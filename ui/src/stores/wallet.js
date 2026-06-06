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

        // 3. Create provider → signer → contract, and wire up MetaMask events
        await this._setupContract()
        this._registerListeners()
      } catch (err) {
        this.error   = err.message ?? 'Connection failed'
        this.account = null
        this.contract = null
      } finally {
        this.isConnecting = false
      }
    },

    // Silently restore a session on page load — uses eth_accounts (no popup) and
    // only reconnects if the wallet is already authorized AND on the right chain.
    // Each wallet call is raced against a timeout so an unresponsive provider
    // can't block app mount (main.js awaits this before first paint).
    async autoConnect() {
      if (!window.ethereum) return
      const withTimeout = (p, ms = 3000) =>
        Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error('wallet timeout')), ms))])
      try {
        const accounts = await withTimeout(window.ethereum.request({ method: 'eth_accounts' }))
        if (!accounts?.length) return
        const chainId = await withTimeout(window.ethereum.request({ method: 'eth_chainId' }))
        if (parseInt(chainId, 16) !== CHAIN_ID) return
        this.account = accounts[0]
        await withTimeout(this._setupContract())
        this._registerListeners()
      } catch {
        // Unresponsive provider or no restorable session — stay disconnected so
        // the app still mounts.
        this.account = null
        this.contract = null
      }
    },

    // Build provider → signer → contract for the current account.
    async _setupContract() {
      const browserProvider = markRaw(new BrowserProvider(window.ethereum, CHAIN_ID))
      const signer          = await browserProvider.getSigner()
      this.provider = browserProvider
      this.contract = markRaw(
        new Contract(CONTRACT_ADDRESS, TrustChainArtifact.abi, signer)
      )
    },

    // React to MetaMask account/chain changes (registered at most once).
    _registerListeners() {
      if (listenersRegistered) return
      listenersRegistered = true
      window.ethereum.on('accountsChanged', async (accs) => {
        if (accs.length === 0) {
          this.disconnect()
        } else {
          this.account = accs[0]
          try {
            await this._setupContract()
          } catch {
            this.error = 'Failed to update signer after account switch.'
          }
        }
      })
      window.ethereum.on('chainChanged', () => window.location.reload())
    },

    disconnect() {
      this.account  = null
      this.contract = null
      this.provider = null
      this.error    = null
    },
  },
})
