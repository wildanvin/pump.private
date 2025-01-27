import { useState, useEffect } from 'react';
import { getInstance } from '../../fhevmjs';
import { Eip1193Provider, Provider /*ZeroAddress*/ } from 'ethers';
import { ethers } from 'ethers';

import EncryptedCounter2 from '../../../../hardhat/deployments/sepolia/EncryptedCounter2.json';

const toHexString = (bytes: Uint8Array) =>
  '0x' +
  bytes.reduce((str, byte) => str + byte.toString(16).padStart(2, '0'), '');

export type Counter2Props = {
  account: string;
  provider: Eip1193Provider;
  readOnlyProvider: Provider;
};

export const Counter2 = ({
  account,
  provider,
  readOnlyProvider,
}: Counter2Props) => {
  //   const [contractAddress, setContractAddress] = useState(ZeroAddress);
  const contractAddress = EncryptedCounter2.address;
  const [handles, setHandles] = useState<Uint8Array[]>([]);
  const [encryption, setEncryption] = useState<Uint8Array>();

  const [inputValue, setInputValue] = useState('');
  const [chosenValue, setChosenValue] = useState('0');

  const handleConfirmValue = () => {
    setChosenValue(inputValue);
    console.log(`contract is: ${contractAddress}`);
    console.log(`account is: ${account}`);
  };

  const instance = getInstance();

  const encrypt = async (val: bigint) => {
    const now = Date.now();

    try {
      const result = await instance
        .createEncryptedInput(contractAddress, account)
        .add8(val)
        .encrypt();
      console.log(`Took ${(Date.now() - now) / 1000}s`);
      setHandles(result.handles);
      setEncryption(result.inputProof);
    } catch (e) {
      console.error('Encryption error:', e);
    }
  };

  const incrementBy = async () => {
    const contract = new ethers.Contract(
      contractAddress,
      ['function incrementBy(bytes32,bytes)'],
      provider,
    );
    const signer = await provider.getSigner();
    const tx = await contract
      .connect(signer)
      .incrementBy(toHexString(handles[0]), toHexString(encryption));
    await tx.wait();
  };

  return (
    <>
      <div>
        <input
          type="number"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          placeholder="Enter a number"
        />{' '}
        <button onClick={handleConfirmValue}>OK</button>
        {chosenValue !== null && (
          <div>
            <p>You chose: {chosenValue}</p>
          </div>
        )}
        <button onClick={() => encrypt(BigInt(chosenValue))}>
          {' '}
          Encrypt {chosenValue}
        </button>
        <div>
          <div>This is an encryption on {chosenValue}:</div>
          <div>Handle: {handles.length ? toHexString(handles[0]) : ''}</div>
          <div>Input Proof: {encryption ? toHexString(encryption) : ''}</div>
        </div>
        <button onClick={incrementBy}>Increment by {chosenValue}</button>
      </div>
    </>
  );
};
