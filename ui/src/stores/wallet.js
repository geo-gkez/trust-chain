import { defineStore } from 'pinia'
import { markRaw } from 'vue'
import { BrowserProvider, Contract } from 'ethers'
import TrustChainArtifact from '@trustchain-abi'

const CHAIN_ID_HEX = import.meta.env.VITE_CHAIN_ID      ?? '0x7a69'
const CHAIN_NAME   = import.meta.env.VITE_CHAIN_NAME     ?? 'Anvil Local'
const RPC_URL      = import.meta.env.VITE_RPC_URL         ?? 'http://127.0.0.1:8545'
const CHAIN_ID     = parseInt(CHAIN_ID_HEX, 16)
const CONTRACT_ADDRESS = import.meta.env.VITE_CONTRACT_ADDRESS

// Prevents listener accumulation if connect() is called multiple times
let listenersRegistered = false

export const useWalletStore = defineStore('wallet', {
  state: () => ({
    account:      null,   // connected wallet address
    contract:     null,   // ethers Contract instance
    provider:     null,   // ethers BrowserProvider
    error:        null,   // error message string
    isConnecting: false,
  }),

  getters: {
    isConnected:  (state) => !!state.account && !!state.contract,
    shortAddress: (state) => state.account
      ? `${state.account.slice(0, 6)}…${state.account.slice(-4)}`
      : null,
  },

  actions: {
    async connect() {
      if (!window.ethereum) {
        this.error = 'MetaMask not found. Please install it.'
        return
      }
      this.isConnecting = true
      this.error = null
      try {
        // 1. Ask MetaMask to show the account selector
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
        this.account = accounts[0]

        // 2. Switch to Anvil chain, or add it if MetaMask doesn't know it yet
        try {
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: CHAIN_ID_HEX }],
          })
        } catch (switchErr) {
          if (switchErr.code === 4902) {
            await window.ethereum.request({
              method: 'wallet_addEthereumChain',
              params: [{
                chainId: CHAIN_ID_HEX,
                chainName: CHAIN_NAME,
                nativeCurrency: { name: 'ETH', symbol: 'ETH', decimals: 18 },
                rpcUrls: [RPC_URL],
              }],
            })
          } else {
            throw switchErr
          }
        }

        // 3. Create provider → signer → contract
        const browserProvider = markRaw(new BrowserProvider(window.ethereum, CHAIN_ID))
        const signer          = await browserProvider.getSigner()
        this.provider = browserProvider
        this.contract = markRaw(
          new Contract(CONTRACT_ADDRESS, TrustChainArtifact.abi, signer)
        )

        // 4. React to MetaMask events (only register once)
        if (!listenersRegistered) {
          listenersRegistered = true
          window.ethereum.on('accountsChanged', (accs) => {
            if (accs.length === 0) this.disconnect()
            else { this.account = accs[0]; this.connect() }
          })
          window.ethereum.on('chainChanged', () => window.location.reload())
        }
      } catch (err) {
        this.error   = err.message ?? 'Connection failed'
        this.account = null
        this.contract = null
      } finally {
        this.isConnecting = false
      }
    },

    disconnect() {
      this.account  = null
      this.contract = null
      this.provider = null
      this.error    = null
    },
  },
})
