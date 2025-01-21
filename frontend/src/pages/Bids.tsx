import React from 'react';
import { Bid } from '../components/Bid';

interface Bid {
  tokenName: string;
  tokenPurpose: string;
  timeRemaining: number; // Time in seconds
  address: string;
}

const Bids: React.FC = () => {
  const mockData: Bid[] = [
    {
      tokenName: 'MyToken',
      tokenPurpose: 'Make Ecuador great once, just once',
      timeRemaining: 4800,
      address: '0x4b2b0D5eE2857fF41B40e3820cDfAc8A9cA60d9f',
    },
    {
      tokenName: 'EcoToken',
      tokenPurpose: 'Support local projects',
      timeRemaining: 3600,
      address: '0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc',
    },
    {
      tokenName: 'SaveTheRainforest',
      tokenPurpose: 'Conservation funding',
      timeRemaining: 7200,
      address: '0xE2Bb56ee936fd6433DC0F6e7e3b8365C906AA057',
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
            address={bid.address}
          />
        ))}
      </section>
    </>
  );
};

export default Bids;
