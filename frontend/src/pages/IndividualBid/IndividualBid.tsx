import { useState, ChangeEvent } from 'react';
import { useParams } from 'react-router-dom';
import './IndividualBid.css';

interface IndividualBidForm {
  tokensWanted: string;
  ethPerToken: string;
  totalToDeposit: string;
}

export function IndividualBid(): JSX.Element {
  const { address } = useParams<{ address: string }>();
  const [formData, setFormData] = useState<IndividualBidForm>({
    tokensWanted: '',
    ethPerToken: '',
    totalToDeposit: '',
  });

  const handleChange = (e: ChangeEvent<HTMLInputElement>): void => {
    const { id, value } = e.target;
    setFormData((prevState) => {
      const updatedFormData = {
        ...prevState,
        [id]: value,
      };
      if (id === 'tokensWanted' || id === 'ethPerToken') {
        const tokens = parseFloat(updatedFormData.tokensWanted) || 0;
        const ethPerToken = parseFloat(updatedFormData.ethPerToken) || 0;
        updatedFormData.totalToDeposit = (tokens * ethPerToken).toFixed(2);
      }
      return updatedFormData;
    });
  };

  const handleSubmit = (): void => {
    console.log('Bid Submitted:', { ...formData, address });
  };

  return (
    <div className="container">
      <p className="address">Token address: {address}</p>
      <div className="input-group">
        <label className="label" htmlFor="tokensWanted">
          Tokens you want:
        </label>
        <input
          className="input"
          type="text"
          id="tokensWanted"
          value={formData.tokensWanted}
          onChange={handleChange}
          placeholder="Enter tokens wanted"
        />
      </div>
      <div className="input-group">
        <label className="label" htmlFor="ethPerToken">
          Eth per token:
        </label>
        <input
          className="input"
          type="text"
          id="ethPerToken"
          value={formData.ethPerToken}
          onChange={handleChange}
          placeholder="Enter ETH per token"
        />
      </div>
      <div className="input-group">
        <label className="label">Total to deposit:</label>
        <p className="total">{formData.totalToDeposit || '0.00'} ETH</p>
      </div>
      <button className="button" onClick={handleSubmit}>
        Deposit
      </button>
    </div>
  );
}
