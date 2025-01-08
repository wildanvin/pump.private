import React from 'react';
import { Bid } from '../components/Bid';

interface Bid {
  tokenName: string;
  tokenPurpose: string;
  timeRemaining: number; // Time in seconds
}

const Bids: React.FC = () => {
  const mockData: Bid[] = [
    {
      tokenName: 'MyToken',
      tokenPurpose: 'Make Ecuador great once, just once',
      timeRemaining: 4800,
    },
    {
      tokenName: 'EcoToken',
      tokenPurpose: 'Support local projects',
      timeRemaining: 3600,
    },
    {
      tokenName: 'SaveTheRainforest',
      tokenPurpose: 'Conservation funding',
      timeRemaining: 7200,
    },
  ];

  return (
    <>
      <section className="heading">
        <h1>Bids</h1>
      </section>
      <section>
        {mockData.map((bid, index) => (
          <Bid
            key={index}
            tokenName={bid.tokenName}
            tokenPurpose={bid.tokenPurpose}
            timeRemaining={bid.timeRemaining}
          />
        ))}
      </section>
    </>
  );
};

export default Bids;
