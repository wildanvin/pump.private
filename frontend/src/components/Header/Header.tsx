import { ImHammer2 } from 'react-icons/im';
import { GiSpikyExplosion } from 'react-icons/gi';
import { Link } from 'react-router-dom';
import './Header.css'; // Ensure you link the CSS file

export function Header() {
  return (
    <header className="header">
      <div className="logo">
        <Link to="/">pump.private</Link>
      </div>
      <ul className="nav-list">
        <li className="nav-item">
          <Link to="/createERC20" className="nav-link">
            <GiSpikyExplosion className="icon" /> Create token
          </Link>
        </li>
        <li className="nav-item">
          <Link to="/bid" className="nav-link">
            <ImHammer2 className="icon" /> Bid
          </Link>
        </li>
        <li className="nav-item">
          <Link to="/example" className="nav-link">
            Example
          </Link>
        </li>
      </ul>
    </header>
  );
}
