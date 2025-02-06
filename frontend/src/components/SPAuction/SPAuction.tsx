import { useState, ChangeEvent } from 'react';
import { getInstance } from '../../fhevmjs';
import { Eip1193Provider, Provider /*ZeroAddress*/ } from 'ethers';
import { ethers } from 'ethers';
import '../components.css';

interface IndividualBidForm {
  quantity: string;
  price: string;
  totalToDeposit: string;
}

import EncryptedSPAuction from '../../../../hardhat/deployments/sepolia/ImprovedSinglePriceAuction2.json';

const toHexString = (bytes: Uint8Array) =>
  '0x' +
  bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, '0'), '');

export type SPAuctionProps = {
  account: string;
  provider: Eip1193Provider;
  readOnlyProvider: Provider;
};

export const SPAuction = ({
  account,
  provider,
  readOnlyProvider,
}: SPAuctionProps) => {
  const [formData, setFormData] = useState<IndividualBidForm>({
    quantity: '',
    price: '',
    totalToDeposit: '',
  });

  const contractAddress = EncryptedSPAuction.address;
  const [handles, setHandles] = useState<Uint8Array[]>([]);
  const [encryption, setEncryption] = useState<Uint8Array>();

  const handleChange = (e: ChangeEvent<HTMLInputElement>): void => {
    const { id, value } = e.target;
    setFormData((prevState) => {
      const updatedFormData = {
        ...prevState,
        [id]: value,
      };
      if (id === 'quantity' || id === 'price') {
        const quantity = parseFloat(updatedFormData.quantity) || 0;
        const price = parseFloat(updatedFormData.price) || 0;
        updatedFormData.totalToDeposit = (quantity * price).toFixed(2);
      }
      return updatedFormData;
    });
  };

  const instance = getInstance();

  const encrypt = async (quantity: bigint, price: bigint) => {
    const now = Date.now();

    try {
      const result = await instance
        .createEncryptedInput(contractAddress, account)
        .add64(quantity)
        .add64(price)
        .encrypt();
      console.log(`Took ${(Date.now() - now) / 1000}s`);
      setHandles(result.handles);
      setEncryption(result.inputProof);
      console.log(`quantity: ${formData.quantity}`);
      console.log(`price: ${formData.price}`);
    } catch (e) {
      console.error('Encryption error:', e);
    }
  };

  const placeBid = async () => {
    const contract = new ethers.Contract(
      contractAddress,
      ['function placeBid(bytes32,bytes32,bytes)'],
      provider,
    );
    const signer = await provider.getSigner();
    const tx = await contract.connect(signer).placeBid(
      toHexString(handles[0]), // quantity
      toHexString(handles[1]), // price
      toHexString(encryption), // proof
    );
    await tx.wait();
  };

  return (
    <>
      <div className="container">
        <div className="input-group">
          <label className="label" htmlFor="quantity">
            Tokens you want:
          </label>
          <input
            className="input"
            type="text"
            id="quantity"
            value={formData.quantity}
            onChange={handleChange}
            placeholder="Enter tokens wanted"
          />
        </div>
        <div className="input-group">
          <label className="label" htmlFor="price">
            $PR0OVI per token:
          </label>
          <input
            className="input"
            type="text"
            id="price"
            value={formData.price}
            onChange={handleChange}
            placeholder="Enter $PROOVI per token"
          />
        </div>
        <div>
          <div className="encryption-details">
            <div>
              Quantity Handle: {handles.length ? toHexString(handles[0]) : ''}
            </div>
            <div>
              Price Handle: {handles.length ? toHexString(handles[1]) : ''}
            </div>
            <div>Input Proof: {encryption ? toHexString(encryption) : ''}</div>
          </div>
          <button
            className="button"
            onClick={() =>
              encrypt(BigInt(formData.quantity), BigInt(formData.price))
            }
          >
            Encrypt
          </button>
        </div>

        <div className="input-group">
          <label className="label">Total to deposit:</label>
          <p className="total">{formData.totalToDeposit || '0.00'} $PROOVI</p>
        </div>
        <button className="button" onClick={placeBid}>
          Place BID
        </button>
      </div>
    </>
  );
};
