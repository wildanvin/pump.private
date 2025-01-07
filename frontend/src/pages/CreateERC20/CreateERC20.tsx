import { useState, ChangeEvent } from 'react';
import './CreateERC20.css';

interface FormData {
  name: string;
  symbol: string;
  purpose: string;
}

export function CreateERC20(): JSX.Element {
  const [formData, setFormData] = useState<FormData>({
    name: '',
    symbol: '',
    purpose: '',
  });

  const handleChange = (
    e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>,
  ): void => {
    const { id, value } = e.target;
    setFormData((prevState) => ({
      ...prevState,
      [id]: value,
    }));
  };

  const handleSubmit = (): void => {
    console.log('Form Data:', formData);
  };

  return (
    <div className="container">
      <div className="input-group">
        <label className="label" htmlFor="name">
          Name:
        </label>
        <input
          className="input"
          type="text"
          id="name"
          value={formData.name}
          onChange={handleChange}
          placeholder="Enter name"
        />
      </div>
      <div className="input-group">
        <label className="label" htmlFor="symbol">
          Symbol:
        </label>
        <input
          className="input"
          type="text"
          id="symbol"
          value={formData.symbol}
          onChange={handleChange}
          placeholder="Enter symbol"
        />
      </div>
      <div>
        <label className="label" htmlFor="purpose">
          Purpose:
        </label>
        <textarea
          className="textarea"
          id="purpose"
          rows={3}
          value={formData.purpose}
          onChange={handleChange}
          placeholder="Enter purpose"
        ></textarea>
      </div>
      <button className="button" onClick={handleSubmit}>
        Create
      </button>
    </div>
  );
}
