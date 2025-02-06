import { useEffect, useState } from 'react';
import { Devnet } from './components/Devnet';
import { Counter2 } from './components/Counter2';
import { SPAuction } from './components/SPAuction';
import Home from './pages/Home';
import { Header } from './components/Header';
import { CreateERC20 } from './pages/CreateERC20';
import { IndividualBid } from './pages/IndividualBid';
import Bids from './pages/Bids';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';

import { init } from './fhevmjs';
import './App.css';
import { Connect } from './components/Connect';

function App() {
  const [isInitialized, setIsInitialized] = useState(false);

  useEffect(() => {
    init()
      .then(() => {
        setIsInitialized(true);
      })
      .catch(() => setIsInitialized(false));
  }, []);

  if (!isInitialized) return null;

  return (
    <>
      <Router>
        <Header />
        <Routes>
          <Route path="/" element={<Home />}></Route>
          <Route path="/createERC20" element={<CreateERC20 />}></Route>
          <Route path="/bids" element={<Bids />}></Route>
          <Route path="/bid/:address" element={<IndividualBid />}></Route>
          <Route
            path="/sp-auction"
            element={
              <Connect>
                {(account, provider, readOnlyProvider) => (
                  <SPAuction
                    account={account}
                    provider={provider}
                    readOnlyProvider={readOnlyProvider}
                  />
                )}
              </Connect>
            }
          ></Route>
          <Route
            path="/counter2"
            element={
              <Connect>
                {(account, provider, readOnlyProvider) => (
                  <Counter2
                    account={account}
                    provider={provider}
                    readOnlyProvider={readOnlyProvider}
                  />
                )}
              </Connect>
            }
          ></Route>
          <Route
            path="/example"
            element={
              <Connect>
                {(account, provider, readOnlyProvider) => (
                  <Devnet
                    account={account}
                    provider={provider}
                    readOnlyProvider={readOnlyProvider}
                  />
                )}
              </Connect>
            }
          ></Route>
        </Routes>

        <p className="read-the-docs">
          <a href="https://docs.zama.ai/fhevm">
            See the documentation for more information
          </a>
        </p>
      </Router>
    </>
  );
}

export default App;
