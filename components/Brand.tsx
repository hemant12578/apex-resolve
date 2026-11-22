import Link from "next/link";

export default function Brand() {
  return <Link className="brand" href="/" aria-label="Apex Resolve home">
    <span className="brand-mark" aria-hidden="true"><i /><i /></span>
    <span>Apex<span className="brand-light">Resolve</span></span>
  </Link>;
}
