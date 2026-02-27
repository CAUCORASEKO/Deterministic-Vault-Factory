import { NavLink } from "react-router-dom";

const navItems = [
  { label: "Dashboard", to: "/dashboard" },
  { label: "New Analysis", to: "/new-analysis" },
  { label: "Vault", to: "/vault" },
  { label: "Evidence Packages", to: "/evidence-packages" },
  { label: "Verify Package", to: "/verify-package" },
  { label: "Settings", to: "/settings" }
];

export default function Sidebar() {
  return (
    <aside style={styles.sidebar}>
      <div style={styles.brandBlock}>
        <div style={styles.brandTitle}>DV</div>
        <div style={styles.brandSubtitle}>Deterministic Vault</div>
      </div>

      <nav style={styles.nav}>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            style={({ isActive }) => ({
              ...styles.link,
              ...(isActive ? styles.activeLink : {})
            })}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>

      <div style={styles.footer}>
        v0.1.0
      </div>
    </aside>
  );
}

const styles: Record<string, React.CSSProperties> = {
  sidebar: {
    width: "260px",
    backgroundColor: "#111827",
    borderRight: "1px solid #1F2937",
    display: "flex",
    flexDirection: "column",
    padding: "24px 16px",
    color: "#F8FAFC"
  },
  brandBlock: {
    marginBottom: "40px"
  },
  brandTitle: {
    fontSize: "22px",
    fontWeight: 700,
    letterSpacing: "1px"
  },
  brandSubtitle: {
    fontSize: "12px",
    color: "#94A3B8",
    marginTop: "4px"
  },
  nav: {
    display: "flex",
    flexDirection: "column",
    gap: "8px"
  },
  link: {
    padding: "10px 14px",
    borderRadius: "6px",
    textDecoration: "none",
    color: "#CBD5E1",
    fontSize: "14px",
    fontWeight: 500,
    transition: "all 0.2s ease"
  },
  activeLink: {
    backgroundColor: "#1E293B",
    color: "#F8FAFC"
  },
  footer: {
    marginTop: "auto",
    fontSize: "11px",
    color: "#64748B",
    paddingTop: "24px",
    borderTop: "1px solid #1F2937"
  }
};