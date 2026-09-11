// Keeps "Give permission" disabled until the consent box is ticked, so a mis-tap
// cannot record permission that was never given. Decline stays available and
// bypasses validation.
(function () {
  var box = document.getElementById('consent_box');
  var approve = document.getElementById('approve-btn');
  if (!box || !approve) {
    return;
  }
  function sync() {
    approve.disabled = !box.checked;
  }
  box.addEventListener('change', sync);
  sync();
})();
