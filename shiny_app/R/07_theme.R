theme_app <- bslib::bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#174c78",
  base_font = bslib::font_google("Inter")
)

app_css <- "
:root {
  --background: #eef3f8;
  --surface: #ffffff;
  --surface-soft: #f7fafc;
  --text-main: #101828;
  --text-muted: #5d6b82;
  --text-light: #ffffff;
  --primary: #174c78;
  --primary-dark: #0b2b45;
  --primary-soft: #e8f2fb;
  --green: #0f7a58;
  --green-soft: #e8f7ef;
  --green-dark: #0c6347;
  --orange: #a55b12;
  --orange-soft: #fff4e6;
  --orange-dark: #834813;
  --border: #e1e8f0;
  --shadow: 0 18px 48px rgba(20, 40, 68, 0.09);
  --shadow-soft: 0 10px 28px rgba(20, 40, 68, 0.06);
  --radius-large: 12px;
  --radius-medium: 10px;
  --radius-small: 8px;
}

body {
  background:
    radial-gradient(circle at top left, rgba(23, 76, 120, 0.14), transparent 34rem),
    linear-gradient(180deg, #eef3f8 0%, #f7f9fc 42%, #ffffff 100%);
  color: var(--text-main);
}

.navbar {
  background: #0b2b45 !important;
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.18);
}

.navbar .navbar-brand,
.navbar .nav-link {
  color: #ffffff !important;
  font-weight: 750;
}

.navbar .nav-link.active {
  color: #bfdbfe !important;
}

.container-fluid {
  padding-left: 7vw !important;
  padding-right: 7vw !important;
}

.institutional-header {
  display: flex;
  justify-content: space-between;
  gap: 28px;
  align-items: center;
  padding: 24px 7vw 10px;
}

.institutional-main {
  display: flex;
  gap: 18px;
  align-items: center;
  min-width: 320px;
}

.logo-geocis {
  width: 88px;
  height: 88px;
  object-fit: contain;
}

.institutional-text {
  display: grid;
  gap: 4px;
}

.institutional-text span {
  color: var(--text-muted);
  font-size: 0.92rem;
  font-weight: 700;
}

.institutional-text strong {
  color: #111827;
  font-size: 1rem;
  line-height: 1.35;
}

.institutional-logo-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 18px;
  align-items: center;
}

.logo-institution {
  display: block;
  max-width: 100%;
  object-fit: contain;
  filter: saturate(0.95);
}

.logo-solos {
  height: 54px;
}

.logo-esalq {
  height: 48px;
  max-width: 260px;
}

.logo-usp {
  height: 44px;
  max-width: 150px;
}

.logo-fapesp {
  height: 38px;
  max-width: 170px;
}

.support-logo-box {
  display: flex;
  gap: 10px;
  align-items: center;
  padding-left: 18px;
  border-left: 1px solid rgba(102, 112, 133, 0.24);
}

.support-logo-box span {
  color: var(--text-muted);
  font-size: 0.76rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.app-hero-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) minmax(300px, 0.65fr);
  gap: 24px;
  align-items: stretch;
  margin-top: 20px;
  margin-bottom: 24px;
}

.app-hero {
  background: rgba(255, 255, 255, 0.82);
  backdrop-filter: blur(14px);
  border: 1px solid rgba(255, 255, 255, 0.78);
  border-radius: var(--radius-large);
  padding: 34px;
  box-shadow: var(--shadow);
}

.hero-badge,
.section-kicker {
  display: inline-flex;
  width: fit-content;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
  padding: 8px 14px;
  border-radius: 8px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 0.84rem;
  font-weight: 850;
  letter-spacing: 0.02em;
}

.app-hero h1 {
  font-weight: 900;
  letter-spacing: -0.055em;
  color: #0f172a;
  font-size: clamp(2.2rem, 4.6vw, 4.4rem);
  line-height: 0.98;
  margin-bottom: 18px;
}

.app-hero p {
  color: #475467;
  margin-bottom: 0;
  max-width: 920px;
  line-height: 1.72;
  font-size: 1.05rem;
}

.hero-summary-card {
  position: relative;
  overflow: hidden;
  padding: 28px;
  border-radius: var(--radius-large);
  color: var(--text-light);
  background: #0b2b45;
  box-shadow: var(--shadow);
}

.hero-summary-card::after {
  position: absolute;
  top: -90px;
  right: -80px;
  width: 220px;
  height: 220px;
  content: '';
  border-radius: 50%;
  background: rgba(59, 130, 246, 0.24);
}

.summary-label {
  display: block;
  margin-bottom: 18px;
  color: #bfdbfe;
  font-size: 0.9rem;
  font-weight: 850;
}

.summary-main {
  margin-bottom: 10px;
  font-size: 3.2rem;
  font-weight: 900;
  line-height: 1;
}

.hero-summary-card p {
  margin: 0 0 22px;
  color: #cbd5e1;
  line-height: 1.62;
}

.summary-list {
  display: grid;
  gap: 12px;
}

.summary-list div {
  display: flex;
  justify-content: space-between;
  gap: 20px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.12);
}

.summary-list span {
  color: #cbd5e1;
}

.summary-list strong {
  color: #ffffff;
}

.metric-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px;
  margin-bottom: 24px;
}

.metric-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-medium);
  padding: 20px;
  box-shadow: var(--shadow-soft);
  min-height: 112px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.metric-card span {
  display: block;
  color: var(--text-muted);
  font-weight: 800;
  font-size: 0.86rem;
  margin-bottom: 10px;
}

.metric-card strong {
  display: block;
  color: #101828;
  font-size: 2.2rem;
  line-height: 1;
  letter-spacing: -0.04em;
}

.section-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 26px;
  box-shadow: var(--shadow-soft);
  margin-bottom: 24px;
}

.section-card h2 {
  font-weight: 850;
  letter-spacing: -0.035em;
  margin-bottom: 16px;
}

.status-ok {
  color: var(--green);
  background: var(--green-soft);
  border-radius: 8px;
  padding: 7px 13px;
  font-weight: 850;
  display: inline-flex;
  margin-bottom: 14px;
}

.status-warning {
  color: var(--orange);
  background: var(--orange-soft);
  border-radius: 8px;
  padding: 7px 13px;
  font-weight: 850;
  display: inline-flex;
}

.form-layout {
  display: grid;
  grid-template-columns: minmax(0, 0.9fr) minmax(340px, 0.55fr);
  gap: 24px;
  align-items: start;
}

.form-layout .shiny-input-container {
  width: 100% !important;
  max-width: none !important;
}

.form-layout .selectize-control {
  width: 100% !important;
}

.form-layout .selectize-dropdown {
  width: 100% !important;
  min-width: 100% !important;
}

.form-layout .form-control {
  width: 100% !important;
}

.form-section-title {
  font-weight: 850;
  margin-top: 12px;
  margin-bottom: 14px;
  color: #101828;
}

.user-info-box {
  background: var(--surface-soft);
  border: 1px solid var(--border);
  border-radius: var(--radius-medium);
  padding: 18px;
  margin-top: 10px;
  margin-bottom: 18px;
}

.user-info-box span {
  display: block;
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 800;
  margin-bottom: 4px;
}

.user-info-box strong {
  display: block;
  color: #101828;
  margin-bottom: 10px;
}

.empty-preview,
.preview-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 24px;
  box-shadow: var(--shadow-soft);
  position: sticky;
  top: 86px;
}

.empty-preview h3,
.preview-card h3 {
  font-weight: 850;
  letter-spacing: -0.035em;
}

.empty-preview p {
  color: var(--text-muted);
  margin-bottom: 0;
}

.preview-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 18px;
}

.preview-status {
  padding: 8px 12px;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 850;
  white-space: nowrap;
}

.preview-approved {
  color: var(--green);
  background: var(--green-soft);
}

.preview-pending {
  color: var(--orange);
  background: var(--orange-soft);
}

.preview-neutral {
  color: var(--text-muted);
  background: #f1f5f9;
}

.preview-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 18px;
}

.preview-grid div {
  padding: 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: var(--surface-soft);
}

.preview-grid span,
.preview-reasons span {
  display: block;
  color: var(--text-muted);
  font-size: 0.78rem;
  font-weight: 800;
  margin-bottom: 6px;
}

.preview-grid strong {
  color: #111827;
  font-size: 0.9rem;
  line-height: 1.35;
}

.preview-reasons {
  padding: 16px;
  background: #f8fafc;
  border-radius: var(--radius-medium);
  margin-bottom: 14px;
}

.preview-reasons p {
  margin-bottom: 0;
  color: #475467;
  line-height: 1.55;
}

.preview-note {
  color: var(--text-muted);
  font-size: 0.9rem;
  margin-bottom: 0;
}

.submit-area {
  margin-top: 18px;
}

.submit-area .btn {
  width: 100%;
  border-radius: 8px;
  font-weight: 850;
  min-height: 44px;
}

.public-status-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
}

.public-machine-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 26px;
  box-shadow: var(--shadow-soft);
}

.public-machine-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 18px;
}

.public-machine-header h3 {
  margin: 0 0 5px;
  font-size: 1.55rem;
  font-weight: 900;
  letter-spacing: -0.04em;
}

.public-machine-header span {
  color: var(--text-muted);
  font-weight: 700;
}

.machine-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: fit-content;
  padding: 8px 12px;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 900;
  white-space: nowrap;
}

.machine-free {
  color: var(--green);
  background: var(--green-soft);
}

.machine-busy {
  color: var(--orange);
  background: var(--orange-soft);
}

.public-machine-body {
  min-height: 96px;
  padding: 18px;
  border: 1px solid var(--border);
  border-radius: var(--radius-medium);
  background: var(--surface-soft);
  margin-bottom: 16px;
}

.public-machine-body p {
  margin-bottom: 8px;
  color: #475467;
  line-height: 1.55;
}

.public-machine-body p:last-child {
  margin-bottom: 0;
}

.public-machine-specs {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.public-machine-specs span {
  padding: 7px 11px;
  border-radius: 8px;
  background: var(--primary-soft);
  color: var(--primary);
  font-size: 0.78rem;
  font-weight: 850;
}

.computer-card-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
}

.computer-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 26px;
  box-shadow: var(--shadow-soft);
}

.computer-card-featured {
  border-color: rgba(23, 76, 120, 0.25);
  background:
    radial-gradient(circle at top right, rgba(23, 76, 120, 0.08), transparent 18rem),
    #ffffff;
}

.computer-card-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 18px;
}

.computer-card h3 {
  margin: 0 0 5px;
  font-size: 1.45rem;
  font-weight: 850;
  letter-spacing: -0.035em;
}

.computer-card-header span {
  color: var(--text-muted);
  font-weight: 650;
}

.computer-card p {
  color: #475467;
  line-height: 1.65;
  margin-bottom: 20px;
}

.status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: fit-content;
  padding: 8px 12px;
  border-radius: 8px;
  font-size: 0.8rem;
  font-weight: 850;
  white-space: nowrap;
}

.status-available {
  color: var(--green);
  background: var(--green-soft);
}

.computer-spec-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.computer-spec-grid div {
  padding: 15px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: var(--surface-soft);
}

.computer-spec-grid span {
  display: block;
  margin-bottom: 6px;
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 800;
}

.computer-spec-grid strong {
  color: #111827;
  font-size: 0.92rem;
  line-height: 1.35;
}

.dataTables_wrapper {
  font-size: 0.92rem;
}

table.dataTable {
  border-collapse: collapse !important;
}

table.dataTable thead th {
  background: #f8fafc;
  color: #475467;
  font-weight: 850;
  border-bottom: 1px solid var(--border) !important;
}

table.dataTable tbody td {
  border-top: 1px solid var(--border);
}

/* Pagina��o do DataTable alinhada � paleta navy (sobrep�e o teal do flatly) */
.dataTables_wrapper .dataTables_paginate .paginate_button,
.dataTables_wrapper .pagination .page-link {
  color: var(--primary) !important;
  background: var(--surface) !important;
  border: 1px solid var(--border) !important;
  border-radius: 8px !important;
}

.dataTables_wrapper .dataTables_paginate .paginate_button:hover,
.dataTables_wrapper .pagination .page-link:hover {
  color: var(--text-light) !important;
  background: var(--primary-dark) !important;
  border-color: var(--primary-dark) !important;
}

.dataTables_wrapper .dataTables_paginate .paginate_button.current,
.dataTables_wrapper .dataTables_paginate .paginate_button.current:hover,
.dataTables_wrapper .pagination .page-item.active .page-link {
  color: var(--text-light) !important;
  background: var(--primary) !important;
  border-color: var(--primary) !important;
}

.dataTables_wrapper .dataTables_paginate .paginate_button.disabled,
.dataTables_wrapper .dataTables_paginate .paginate_button.disabled:hover {
  color: var(--text-muted) !important;
  background: var(--surface-soft) !important;
  border-color: var(--border) !important;
}

/* Bot�es de a��o verdes (Aprovar, Enviar) no verde da p�gina */
.btn-success {
  --bs-btn-bg: var(--green);
  --bs-btn-border-color: var(--green);
  --bs-btn-hover-bg: var(--green-dark);
  --bs-btn-hover-border-color: var(--green-dark);
  --bs-btn-active-bg: var(--green-dark);
  --bs-btn-active-border-color: var(--green-dark);
  --bs-btn-disabled-bg: var(--green);
  --bs-btn-disabled-border-color: var(--green);
}

.btn-success:focus,
.btn-success:focus-visible {
  box-shadow: 0 0 0 0.25rem rgba(15, 122, 88, 0.35);
}

/* Rejeitar: �mbar da p�gina */
.btn-warning {
  --bs-btn-color: var(--text-light);
  --bs-btn-bg: var(--orange);
  --bs-btn-border-color: var(--orange);
  --bs-btn-hover-color: var(--text-light);
  --bs-btn-hover-bg: var(--orange-dark);
  --bs-btn-hover-border-color: var(--orange-dark);
  --bs-btn-active-color: var(--text-light);
  --bs-btn-active-bg: var(--orange-dark);
  --bs-btn-active-border-color: var(--orange-dark);
  --bs-btn-disabled-color: var(--text-light);
  --bs-btn-disabled-bg: var(--orange);
  --bs-btn-disabled-border-color: var(--orange);
}

.btn-warning:focus,
.btn-warning:focus-visible {
  box-shadow: 0 0 0 0.25rem rgba(165, 91, 18, 0.35);
}

/* Iniciar uso: navy alinhado � paleta (distinto do Finalizar uso cinza) */
.btn-info {
  --bs-btn-color: var(--text-light);
  --bs-btn-bg: var(--primary);
  --bs-btn-border-color: var(--primary);
  --bs-btn-hover-color: var(--text-light);
  --bs-btn-hover-bg: var(--primary-dark);
  --bs-btn-hover-border-color: var(--primary-dark);
  --bs-btn-active-color: var(--text-light);
  --bs-btn-active-bg: var(--primary-dark);
  --bs-btn-active-border-color: var(--primary-dark);
  --bs-btn-disabled-color: var(--text-light);
  --bs-btn-disabled-bg: var(--primary);
  --bs-btn-disabled-border-color: var(--primary);
}

.btn-info:focus,
.btn-info:focus-visible {
  box-shadow: 0 0 0 0.25rem rgba(23, 76, 120, 0.35);
}

.app-footer {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  align-items: center;
  margin-top: 28px;
  margin-bottom: 20px;
  padding: 24px 26px;
  color: var(--text-muted);
  background: rgba(255, 255, 255, 0.82);
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  box-shadow: var(--shadow-soft);
}

.footer-main {
  display: flex;
  gap: 16px;
  align-items: center;
}

.footer-logo {
  width: 62px;
  height: 62px;
  object-fit: contain;
}

.app-footer p,
.app-footer span {
  margin: 0;
}

.app-footer p {
  margin-bottom: 4px;
  font-weight: 850;
  color: #344054;
}

.footer-support {
  display: flex;
  gap: 12px;
  align-items: center;
}

.footer-support span {
  color: var(--text-muted);
  font-size: 0.76rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.footer-fapesp {
  height: 34px;
  width: auto;
  object-fit: contain;
}

@media (max-width: 1180px) {
  .institutional-header {
    display: block;
  }

  .institutional-logo-row {
    justify-content: flex-start;
    margin-top: 18px;
  }

  .support-logo-box {
    padding-left: 0;
    border-left: none;
  }

  .app-hero-grid,
  .computer-card-grid,
  .form-layout,
  .public-status-grid {
    grid-template-columns: 1fr;
  }

  .metric-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .empty-preview,
  .preview-card {
    position: static;
  }
}

@media (max-width: 760px) {
  .container-fluid,
  .institutional-header {
    padding-left: 20px !important;
    padding-right: 20px !important;
  }

  .institutional-main {
    display: block;
    min-width: 0;
  }

  .logo-geocis {
    width: 76px;
    height: 76px;
    margin-bottom: 12px;
  }

  .institutional-logo-row {
    gap: 14px;
  }

  .logo-solos {
    height: 42px;
  }

  .logo-esalq {
    height: 38px;
    max-width: 220px;
  }

  .logo-usp {
    height: 36px;
    max-width: 120px;
  }

  .logo-fapesp {
    height: 32px;
    max-width: 140px;
  }

  .metric-grid,
  .computer-spec-grid,
  .preview-grid {
    grid-template-columns: 1fr;
  }

  .app-hero,
  .hero-summary-card,
  .section-card,
  .computer-card,
  .app-footer,
  .public-machine-card {
    border-radius: 22px;
  }

  .app-hero {
    padding: 26px;
  }

  .app-footer {
    display: block;
  }

  .footer-main {
    align-items: flex-start;
  }

  .footer-support {
    margin-top: 20px;
  }
}
"
