"""Admin reports, CSV export, and the Publish content action — A-02, A-10, A-11, §23.

Report queries read ``AnalyticsEvent`` directly, which is the primary analytics
store (analytics-spec §1). All date boundaries are UTC and labelled as such
(backend.timezoneHandling).
"""

from __future__ import annotations

import csv
import html
import io
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import Any, Callable

from sqladmin import BaseView, expose
from sqlalchemy import func, select
from sqlalchemy.orm import Session
from starlette.requests import Request
from starlette.responses import HTMLResponse, RedirectResponse, StreamingResponse

from app.admin.auth import current_admin_email, current_admin_id
from app.core.config import settings
from app.core.database import SessionLocal
from app.models.analytics import AnalyticsEvent
from app.models.commerce import PurchaseRecord
from app.models.content import Level, Question
from app.models.enums import UnlockStatus
from app.models.gameplay import LeaderboardEntry
from app.models.user import User
from app.services import analytics, audit, content_pack, gameplay

REPORT_TYPES = (
    "dau_trend",
    "level_funnel",
    "vpc_funnel",
    "iap_conversion",
    "ad_impressions",
    "leaderboard_engagement",
    "content_pool_health",
)


# ------------------------------------------------------------------ date range
def _parse_range(request: Request) -> tuple[datetime, datetime, int]:
    today = datetime.now(timezone.utc).date()
    try:
        days = int(request.query_params.get("days", "30"))
    except ValueError:
        days = 30
    days = max(1, min(days, 365))

    start_param = request.query_params.get("start")
    end_param = request.query_params.get("end")
    try:
        end_date = date.fromisoformat(end_param) if end_param else today
        start_date = (
            date.fromisoformat(start_param) if start_param else end_date - timedelta(days=days - 1)
        )
    except ValueError:
        end_date, start_date = today, today - timedelta(days=days - 1)

    start = datetime.combine(start_date, datetime.min.time(), tzinfo=timezone.utc)
    end = datetime.combine(end_date, datetime.max.time(), tzinfo=timezone.utc)
    return start, end, (end_date - start_date).days + 1


# ------------------------------------------------------------------ report data
def _events(
    db: Session, names: list[str], start: datetime, end: datetime
) -> list[AnalyticsEvent]:
    return list(
        db.execute(
            select(AnalyticsEvent).where(
                AnalyticsEvent.event_name.in_(names),
                AnalyticsEvent.timestamp_utc >= start,
                AnalyticsEvent.timestamp_utc <= end,
            )
        )
        .scalars()
        .all()
    )


def _dau_trend(db: Session, start: datetime, end: datetime) -> tuple[list[str], list[list[Any]]]:
    rows = db.execute(
        select(
            func.date(AnalyticsEvent.timestamp_utc).label("day"),
            func.count(func.distinct(AnalyticsEvent.user_id)),
            func.count(AnalyticsEvent.id),
        )
        .where(
            AnalyticsEvent.event_name == "session_start",
            AnalyticsEvent.timestamp_utc >= start,
            AnalyticsEvent.timestamp_utc <= end,
        )
        .group_by(func.date(AnalyticsEvent.timestamp_utc))
        .order_by(func.date(AnalyticsEvent.timestamp_utc))
    ).all()
    return ["date_utc", "daily_active_users", "sessions"], [
        [str(day), int(users), int(sessions)] for day, users, sessions in rows
    ]


def _level_funnel(
    db: Session, start: datetime, end: datetime
) -> tuple[list[str], list[list[Any]]]:
    counters: dict[int, Counter] = defaultdict(Counter)
    for event in _events(
        db, ["level_started", "level_failed", "level_completed"], start, end
    ):
        level_id = event.properties.get("level_id")
        if isinstance(level_id, int):
            counters[level_id][event.event_name] += 1

    data = []
    for level_id in sorted(counters):
        counts = counters[level_id]
        started = counts["level_started"]
        completed = counts["level_completed"]
        data.append(
            [
                level_id,
                started,
                counts["level_failed"],
                completed,
                round(completed / started * 100, 1) if started else 0.0,
            ]
        )
    return ["level_id", "started", "failed", "completed", "completion_rate_pct"], data


def _vpc_funnel(db: Session, start: datetime, end: datetime) -> tuple[list[str], list[list[Any]]]:
    stages = [
        "vpc_parent_gate_viewed",
        "vpc_path_selected",
        "vpc_email_requested",
        "vpc_email_verified",
        "parental_consent_completed",
        "vpc_consent_denied",
    ]
    counts = Counter(event.event_name for event in _events(db, stages, start, end))
    top = counts.get(stages[0], 0)
    return ["stage", "count", "pct_of_gate_views"], [
        [stage, counts.get(stage, 0), round(counts.get(stage, 0) / top * 100, 1) if top else 0.0]
        for stage in stages
    ]


def _iap_conversion(
    db: Session, start: datetime, end: datetime
) -> tuple[list[str], list[list[Any]]]:
    stages = [
        "iap_prompt_shown",
        "purchase_initiated",
        "purchase_completed",
        "purchase_cancelled",
        "purchase_failed",
        "purchase_restored",
    ]
    counts = Counter(event.event_name for event in _events(db, stages, start, end))
    shown = counts.get("iap_prompt_shown", 0)
    return ["stage", "count", "pct_of_prompts"], [
        [stage, counts.get(stage, 0), round(counts.get(stage, 0) / shown * 100, 1) if shown else 0.0]
        for stage in stages
    ]


def _ad_impressions(
    db: Session, start: datetime, end: datetime
) -> tuple[list[str], list[list[Any]]]:
    buckets: dict[tuple[str, str], Counter] = defaultdict(Counter)
    for event in _events(db, ["ad_viewed", "ad_clicked"], start, end):
        placement = str(event.properties.get("placement") or "unknown")
        day = event.timestamp_utc.date().isoformat()
        buckets[(day, placement)][event.event_name] += 1

    return ["date_utc", "placement", "impressions", "clicks", "ctr_pct"], [
        [
            day,
            placement,
            counts["ad_viewed"],
            counts["ad_clicked"],
            round(counts["ad_clicked"] / counts["ad_viewed"] * 100, 2)
            if counts["ad_viewed"]
            else 0.0,
        ]
        for (day, placement), counts in sorted(buckets.items())
    ]


def _leaderboard_engagement(
    db: Session, start: datetime, end: datetime
) -> tuple[list[str], list[list[Any]]]:
    by_day: dict[str, Counter] = defaultdict(Counter)
    for event in _events(
        db,
        ["leaderboard_viewed", "leaderboard_submitted", "leaderboard_attempt_rejected"],
        start,
        end,
    ):
        by_day[event.timestamp_utc.date().isoformat()][event.event_name] += 1
        if event.event_name == "leaderboard_submitted" and event.properties.get(
            "is_deferred_sync"
        ):
            by_day[event.timestamp_utc.date().isoformat()]["deferred"] += 1

    return ["date_utc", "views", "submissions", "rejected", "deferred_syncs"], [
        [
            day,
            counts["leaderboard_viewed"],
            counts["leaderboard_submitted"],
            counts["leaderboard_attempt_rejected"],
            counts["deferred"],
        ]
        for day, counts in sorted(by_day.items())
    ]


def _content_pool_health(
    db: Session, _start: datetime, _end: datetime
) -> tuple[list[str], list[list[Any]]]:
    """Per-level authoring progress — the launch blocker the operator watches daily."""
    levels = list(db.execute(select(Level).order_by(Level.level_number)).scalars().all())
    data = []
    for level in levels:
        health = gameplay.pool_health(db, level)
        by_type = health["by_variant_type"]
        data.append(
            [
                level.level_number,
                health["live_count"],
                health["min_required"],
                "OK" if health["meets_minimum"] else "BELOW MINIMUM",
                by_type.get("text_qa", 0),
                by_type.get("verse_clue", 0),
                by_type.get("image_clue", 0),
                "yes" if health["playable"] else "no",
            ]
        )
    return (
        [
            "level_number",
            "live_questions",
            "min_required",
            "status",
            "text_qa",
            "verse_clue",
            "image_clue",
            "playable",
        ],
        data,
    )


REPORT_BUILDERS: dict[str, Callable[[Session, datetime, datetime], tuple[list[str], list[list]]]] = {
    "dau_trend": _dau_trend,
    "level_funnel": _level_funnel,
    "vpc_funnel": _vpc_funnel,
    "iap_conversion": _iap_conversion,
    "ad_impressions": _ad_impressions,
    "leaderboard_engagement": _leaderboard_engagement,
    "content_pool_health": _content_pool_health,
}


# --------------------------------------------------------------------- KPI card
def _kpis(db: Session) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    day_ago = now - timedelta(days=1)

    dau = int(
        db.execute(
            select(func.count(func.distinct(AnalyticsEvent.user_id))).where(
                AnalyticsEvent.event_name == "session_start",
                AnalyticsEvent.timestamp_utc >= day_ago,
            )
        ).scalar_one()
    )
    total_users = int(
        db.execute(select(func.count()).select_from(User)).scalar_one()
    )
    live_questions = int(
        db.execute(
            select(func.count())
            .select_from(Question)
            .where(Question.active.is_(True), Question.review_status == "approved")
        ).scalar_one()
    )
    purchases = int(
        db.execute(
            select(func.count())
            .select_from(PurchaseRecord)
            .where(PurchaseRecord.unlock_status == UnlockStatus.UNLOCKED)
        ).scalar_one()
    )
    leaderboard_entries = int(
        db.execute(
            select(func.count())
            .select_from(LeaderboardEntry)
            .where(LeaderboardEntry.revoked.is_(False))
        ).scalar_one()
    )
    pending_consent = int(
        db.execute(
            select(func.count())
            .select_from(User)
            .where(User.account_status == "pending_parental_consent")
        ).scalar_one()
    )

    validation = content_pack.validate_for_publish(db)
    return {
        "dau_24h": dau,
        "total_users": total_users,
        "live_questions": live_questions,
        "launch_target_questions": settings.total_levels * settings.launch_min_questions_per_level,
        "purchases": purchases,
        "leaderboard_entries": leaderboard_entries,
        "pending_consent": pending_consent,
        "content_version": content_pack.current_version(db),
        "levels_below_minimum": len(validation.levels_below_minimum),
        "publish_ready": validation.ok,
    }


# ------------------------------------------------------------------ HTML render
_PAGE_CSS = """
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
 margin:0;padding:24px;background:#f6f7fb;color:#1c1a17;}
h1{font-size:1.5rem;margin:0 0 4px;} h2{font-size:1.1rem;margin:28px 0 10px;}
.sub{color:#6b6560;font-size:.9rem;margin-bottom:20px;}
.kpis{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:12px;
 margin-bottom:24px;}
.kpi{background:#fff;border:1px solid #e3e6ef;border-radius:12px;padding:14px 16px;}
.kpi .v{font-size:1.6rem;font-weight:700;} .kpi .l{color:#6b6560;font-size:.82rem;}
.kpi.warn{border-color:#f0c17a;background:#fffaf0;}
.kpi.ok{border-color:#bfe3c6;background:#f4fbf5;}
table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #e3e6ef;
 border-radius:10px;overflow:hidden;font-size:.9rem;}
th{background:#eef1f8;text-align:left;padding:8px 10px;font-weight:600;}
td{padding:8px 10px;border-top:1px solid #eef0f5;}
form.inline{display:inline-block;margin-right:10px;}
input,select,button{padding:8px 10px;border:1px solid #d7dbe7;border-radius:8px;font-size:.9rem;}
button{background:#5c67f2;color:#fff;border:0;cursor:pointer;font-weight:600;}
button.secondary{background:#fff;color:#5c67f2;border:1px solid #5c67f2;}
a.tab{display:inline-block;padding:7px 12px;margin:0 6px 8px 0;border-radius:8px;
 background:#fff;border:1px solid #d7dbe7;text-decoration:none;color:#1c1a17;font-size:.88rem;}
a.tab.active{background:#5c67f2;color:#fff;border-color:#5c67f2;}
.empty{background:#fff;border:1px dashed #d7dbe7;border-radius:10px;padding:28px;
 text-align:center;color:#6b6560;}
.notice{border-radius:10px;padding:12px 14px;margin-bottom:16px;font-size:.9rem;}
.notice.ok{background:#eaf6ec;border:1px solid #b7dfc0;}
.notice.err{background:#fdecea;border:1px solid #f3b7b1;}
.back{font-size:.85rem;color:#5c67f2;text-decoration:none;}
"""


def _layout(title: str, body: str) -> HTMLResponse:
    return HTMLResponse(
        f"<!doctype html><html><head><meta charset='utf-8'>"
        f"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{html.escape(title)} — Anointed Admin</title>"
        f"<style>{_PAGE_CSS}</style></head><body>{body}</body></html>"
    )


def _table(headers: list[str], rows: list[list[Any]], empty_message: str) -> str:
    if not rows:
        return f"<div class='empty'>{html.escape(empty_message)}</div>"
    head = "".join(f"<th>{html.escape(str(header))}</th>" for header in headers)
    body = "".join(
        "<tr>" + "".join(f"<td>{html.escape(str(cell))}</td>" for cell in row) + "</tr>"
        for row in rows
    )
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


# ------------------------------------------------------------------- A-10, A-11
class ReportsView(BaseView):
    name = "Reports"
    icon = "fa-solid fa-chart-pie"
    category = "Reports"

    @expose("/reports", methods=["GET"])
    async def reports(self, request: Request) -> HTMLResponse:
        report_type = request.query_params.get("type", "dau_trend")
        if report_type not in REPORT_BUILDERS:
            report_type = "dau_trend"
        start, end, span_days = _parse_range(request)

        with SessionLocal() as db:
            kpis = _kpis(db)
            headers, rows = REPORT_BUILDERS[report_type](db, start, end)
            analytics.track(
                db,
                "admin_report_viewed",
                admin_user_id=current_admin_id(request),
                platform="web_admin",
                properties={"report_type": report_type, "date_range_days": span_days},
            )
            db.commit()

        kpi_cards = "".join(
            f"<div class='kpi {css}'><div class='v'>{value}</div><div class='l'>{label}</div></div>"
            for label, value, css in [
                ("Daily active users (24h)", kpis["dau_24h"], ""),
                ("Total players", kpis["total_users"], ""),
                (
                    f"Live questions of {kpis['launch_target_questions']} target",
                    kpis["live_questions"],
                    "",
                ),
                ("IAP unlocks", kpis["purchases"], ""),
                ("Leaderboard entries", kpis["leaderboard_entries"], ""),
                ("Awaiting parental consent", kpis["pending_consent"], ""),
                ("Published content version", kpis["content_version"], ""),
                (
                    "Levels below question minimum",
                    kpis["levels_below_minimum"],
                    "ok" if kpis["publish_ready"] else "warn",
                ),
            ]
        )

        tabs = "".join(
            f"<a class='tab {'active' if name == report_type else ''}' "
            f"href='?type={name}&start={start.date()}&end={end.date()}'>"
            f"{html.escape(name.replace('_', ' ').title())}</a>"
            for name in REPORT_TYPES
        )

        export_url = (
            f"/admin/reports/export?type={report_type}"
            f"&start={start.date()}&end={end.date()}"
        )

        body = f"""
        <h1>Reports &amp; analytics</h1>
        <div class='sub'>All dates and times are UTC.
          Range {start.date()} to {end.date()} ({span_days} days).</div>
        <div class='kpis'>{kpi_cards}</div>
        <form class='inline' method='get'>
          <input type='hidden' name='type' value='{html.escape(report_type)}'>
          <label>From <input type='date' name='start' value='{start.date()}'></label>
          <label>To <input type='date' name='end' value='{end.date()}'></label>
          <button type='submit'>Apply</button>
        </form>
        <a class='tab' href='{export_url}'>Export CSV</a>
        <a class='tab' href='/admin/content-publish'>Publish content</a>
        <h2>{html.escape(report_type.replace('_', ' ').title())}</h2>
        <div>{tabs}</div>
        {_table(headers, rows, 'No data for this date range. Try a wider range.')}
        <p><a class='back' href='/admin'>&larr; Back to admin</a></p>
        """
        return _layout("Reports", body)

    @expose("/reports/export", methods=["GET"])
    async def export(self, request: Request) -> StreamingResponse:
        """A-11 CSV export. PDF is deferred post-v1 per inference IA-10."""
        report_type = request.query_params.get("type", "dau_trend")
        if report_type not in REPORT_BUILDERS:
            report_type = "dau_trend"
        start, end, span_days = _parse_range(request)

        with SessionLocal() as db:
            headers, rows = REPORT_BUILDERS[report_type](db, start, end)
            analytics.track(
                db,
                "admin_report_exported",
                admin_user_id=current_admin_id(request),
                platform="web_admin",
                properties={
                    "report_type": report_type,
                    "format": "csv",
                    "date_range_days": span_days,
                    "row_count": len(rows),
                },
            )
            audit.record(
                db,
                "admin_report_exported",
                actor_type="admin",
                actor_id=str(current_admin_id(request) or "admin"),
                detail={
                    "report_type": report_type,
                    "row_count": len(rows),
                    "start_utc": start.isoformat(),
                    "end_utc": end.isoformat(),
                },
            )
            db.commit()

        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(headers)
        writer.writerows(rows)
        buffer.seek(0)

        filename = f"anointed_{report_type}_{start.date()}_{end.date()}.csv"
        return StreamingResponse(
            iter([buffer.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )


# ---------------------------------------------------------------------- §19/§23
class ContentPublishView(BaseView):
    name = "Publish content"
    icon = "fa-solid fa-cloud-arrow-up"
    category = "Content"

    @expose("/content-publish", methods=["GET"])
    async def show(self, request: Request) -> HTMLResponse:
        published = request.query_params.get("published")
        blocked = request.query_params.get("blocked")

        with SessionLocal() as db:
            beta = content_pack.validate_for_publish(
                db, threshold=settings.beta_min_questions_per_level
            )
            launch = content_pack.validate_for_publish(
                db, threshold=settings.launch_min_questions_per_level
            )
            current = content_pack.current_publish(db)
            levels = list(db.execute(select(Level).order_by(Level.level_number)).scalars().all())
            health_rows = [
                [
                    item["level_number"],
                    item["live_count"],
                    item["min_required"],
                    "OK" if item["meets_minimum"] else "BELOW MINIMUM",
                    ", ".join(f"{k}:{v}" for k, v in sorted(item["by_variant_type"].items()))
                    or "none",
                ]
                for item in (gameplay.pool_health(db, level) for level in levels)
            ]

        notice = ""
        if published:
            notice = (
                f"<div class='notice ok'>Published content version "
                f"{html.escape(published)}. Mobile clients pick it up on their next "
                f"manifest check.</div>"
            )
        elif blocked:
            notice = f"<div class='notice err'>{html.escape(blocked)}</div>"

        current_block = (
            f"<p><strong>Current published version:</strong> {current.content_version} "
            f"({current.published_at:%Y-%m-%d %H:%M} UTC, "
            f"{current.pack_size_bytes:,} bytes gzipped)</p>"
            if current
            else "<p><strong>No content has been published yet.</strong> "
            "Mobile clients will fall back to the seed pack shipped in the app binary.</p>"
        )

        body = f"""
        <h1>Publish content</h1>
        <div class='sub'>Publishing bumps <code>content_version</code>, writes a
          ContentPublishRecord, and rebuilds the practice pack. Draft and in-review
          edits stay invisible to players until you publish.</div>
        {notice}
        {current_block}
        <div class='kpis'>
          <div class='kpi {"ok" if beta.ok else "warn"}'>
            <div class='v'>{len(beta.levels_below_minimum)}</div>
            <div class='l'>Levels below beta minimum ({beta.threshold})</div></div>
          <div class='kpi {"ok" if launch.ok else "warn"}'>
            <div class='v'>{len(launch.levels_below_minimum)}</div>
            <div class='l'>Levels below launch target ({launch.threshold})</div></div>
          <div class='kpi'><div class='v'>{beta.total_live_questions}</div>
            <div class='l'>Approved + active questions</div></div>
          <div class='kpi {"ok" if not beta.levels_missing_launch_variety else "warn"}'>
            <div class='v'>{len(beta.levels_missing_launch_variety)}</div>
            <div class='l'>Levels missing text_qa + verse_clue</div></div>
        </div>

        <form class='inline' method='post' action='/admin/content-publish'>
          <input type='hidden' name='threshold' value='{settings.beta_min_questions_per_level}'>
          <input type='text' name='change_summary' placeholder='What changed? (optional)'
                 maxlength='200' size='40'>
          <button type='submit'>Publish (beta bar: {settings.beta_min_questions_per_level}/level)</button>
        </form>
        <form class='inline' method='post' action='/admin/content-publish'>
          <input type='hidden' name='threshold' value='{settings.launch_min_questions_per_level}'>
          <button class='secondary' type='submit'>
            Publish (launch bar: {settings.launch_min_questions_per_level}/level)</button>
        </form>

        <h2>Per-level pool health</h2>
        {_table(
            ["Level", "Live questions", "Minimum", "Status", "By variant type"],
            health_rows,
            "No levels configured yet. Seed the level table first.",
        )}
        <p><a class='back' href='/admin'>&larr; Back to admin</a></p>
        """
        return _layout("Publish content", body)

    @expose("/content-publish", methods=["POST"])
    async def publish(self, request: Request) -> RedirectResponse:
        form = await request.form()
        try:
            threshold = int(str(form.get("threshold", settings.beta_min_questions_per_level)))
        except ValueError:
            threshold = settings.beta_min_questions_per_level
        change_summary = str(form.get("change_summary", "")).strip() or None

        with SessionLocal() as db:
            record, report = content_pack.publish(
                db,
                published_by=current_admin_email(request),
                change_summary=change_summary,
                threshold=threshold,
            )
            if record is None:
                db.rollback()
                return RedirectResponse(
                    f"/admin/content-publish?blocked={html.escape(report.summary())}", 302
                )

            audit.record(
                db,
                "content_published",
                actor_type="admin",
                actor_id=str(current_admin_id(request) or "admin"),
                detail={
                    "content_version": record.content_version,
                    "checksum": record.checksum,
                    "pack_size_bytes": record.pack_size_bytes,
                    "threshold": threshold,
                },
            )
            analytics.track(
                db,
                "admin_content_published",
                admin_user_id=current_admin_id(request),
                platform="web_admin",
                properties={
                    "content_version": record.content_version,
                    "pack_size_bytes": record.pack_size_bytes,
                    "threshold": threshold,
                },
            )
            version = record.content_version
            db.commit()

        return RedirectResponse(f"/admin/content-publish?published={version}", 302)


class AuditLogExportView(BaseView):
    name = "Audit log export"
    icon = "fa-solid fa-file-csv"
    category = "Compliance"

    @expose("/audit-export", methods=["GET"])
    async def export(self, request: Request) -> StreamingResponse:
        """A-12 CSV export of the compliance trail."""
        from app.models.analytics import AuditLog

        start, end, span_days = _parse_range(request)
        with SessionLocal() as db:
            rows = list(
                db.execute(
                    select(AuditLog)
                    .where(AuditLog.occurred_at >= start, AuditLog.occurred_at <= end)
                    .order_by(AuditLog.occurred_at.desc())
                )
                .scalars()
                .all()
            )
            analytics.track(
                db,
                "admin_audit_log_viewed",
                admin_user_id=current_admin_id(request),
                platform="web_admin",
                properties={"filter_applied": bool(request.query_params.get("start"))},
            )
            db.commit()

        buffer = io.StringIO()
        writer = csv.writer(buffer)
        writer.writerow(
            [
                "occurred_at_utc",
                "action",
                "actor_type",
                "actor_id",
                "target_user_id",
                "target_is_under_13",
                "detail",
            ]
        )
        for row in rows:
            writer.writerow(
                [
                    row.occurred_at.isoformat(),
                    row.action,
                    row.actor_type,
                    row.actor_id or "",
                    row.target_user_id or "",
                    row.target_is_under_13,
                    row.detail,
                ]
            )
        buffer.seek(0)
        filename = f"anointed_audit_{start.date()}_{end.date()}.csv"
        return StreamingResponse(
            iter([buffer.getvalue()]),
            media_type="text/csv",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )
