import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import './Bid.css';

interface BidProps {
  tokenName: string;
  tokenPurpose: string;
  timeRemaining: number; // Time in seconds
  address: string; // Ethereum address
}

export const Bid: React.FC<BidProps> = ({
  tokenName,
  tokenPurpose,
  timeRemaining,
  address,
}) => {
  const [timeLeft, setTimeLeft] = useState(timeRemaining);
  const navigate = useNavigate();

  useEffect(() => {
    const timer = setInterval(() => {
      setTimeLeft((prevTime) => Math.max(prevTime - 1, 0));
    }, 1000);

    return () => clearInterval(timer);
  }, []);

  const formatTime = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const handleBidClick = () => {
    navigate(`/bid/${address}`);
  };

  return (
    <div className="container">
      <div className="tokenInfo">
        <p className="tokenText">
          <strong>Token name:</strong> {tokenName}
        </p>
        <p className="tokenText">
          <strong>Token purpose:</strong> {tokenPurpose}
        </p>
      </div>
      <div className="timerContainer">
        <span className="timer">{formatTime(timeLeft)}</span>
      </div>
      <button className="button" onClick={handleBidClick}>
        Enter Bid
      </button>
      <p className="helperText">Time remaining to bid</p>
    </div>
  );
};
