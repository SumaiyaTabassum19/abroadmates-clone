(() => {
  function initResponsiveNavigation() {
    document.querySelectorAll(".nav-toggle, .menu-toggle").forEach((toggle) => {
      if (toggle.dataset.navReady === "true") return;
      const shell = toggle.closest("header, .navbar, .topbar, .profile-header, .fm-header, .md-header, .site-header") || toggle.parentElement;
      const controlledId = toggle.getAttribute("aria-controls");
      const nav = (controlledId && document.getElementById(controlledId)) ||
        shell?.querySelector(".main-nav, .responsive-nav-links, .nav-links, .header-nav, nav");
      if (!nav) return;

      toggle.dataset.navReady = "true";
      nav.classList.add("responsive-menu-target");
      toggle.setAttribute("aria-expanded", "false");

      const close = () => {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
        toggle.setAttribute("aria-label", "Open navigation");
      };
      const open = () => {
        nav.classList.add("is-open");
        toggle.setAttribute("aria-expanded", "true");
        toggle.setAttribute("aria-label", "Close navigation");
      };

      toggle.addEventListener("click", (event) => {
        event.stopPropagation();
        toggle.getAttribute("aria-expanded") === "true" ? close() : open();
      });
      nav.querySelectorAll("a").forEach((link) => link.addEventListener("click", () => {
        if (window.matchMedia("(max-width: 950px)").matches) close();
      }));
      document.addEventListener("click", (event) => {
        if (window.matchMedia("(max-width: 950px)").matches &&
            !nav.contains(event.target) && !toggle.contains(event.target)) close();
      });
      document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") close();
      });
      window.addEventListener("resize", () => {
        if (window.innerWidth > 950) close();
      });
    });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initResponsiveNavigation);
  } else initResponsiveNavigation();
})();