import React, { useState, useEffect } from 'react';
import './Bid.css';

interface BidProps {
  tokenName: string;
  tokenPurpose: string;
  timeRemaining: number; // Time in seconds
}

export const Bid: React.FC<BidProps> = ({
  tokenName,
  tokenPurpose,
  timeRemaining,
}) => {
  const [timeLeft, setTimeLeft] = useState(timeRemaining);

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
        <button className="button">Enter Bid</button>
      </div>
      <p className="helperText">Time remaining to bid</p>
    </div>
  );
};
