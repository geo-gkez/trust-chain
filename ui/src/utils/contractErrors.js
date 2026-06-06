import { Interface } from 'ethers'
import TrustChainArtifact from '@trustchain-abi'

const iface = new Interface(TrustChainArtifact.abi)

const ERROR_MESSAGES = {
  ZeroAddress:             'Address cannot be zero.',
  AlreadyRegistered:       'This address is already registered.',
  NotRegistered:           'This address is not registered.',
  Unauthorized:            'You do not have permission for this action.',
  SelfDeactivation:        'You cannot deactivate your own account.',
  BatchNotFound:           'Batch not found.',
  DuplicateSerial:         'A batch with this serial number already exists.',
  InvalidTransition:       'This status change is not allowed.',
  NotCurrentHolder:        'You are not the current holder of this batch.',
  NoPendingCustody:        'There is no pending custody offer for this batch.',
  NotPendingHolder:        'This custody offer was not made to your address.',
  BatchExpired:            'This batch has expired and cannot move forward.',
  CannotDistributeRecalled:'A recalled batch cannot be distributed.',
  BatchNotRecalled:        'This batch has not been recalled.',
  InvalidExpiryDate:       'Expiry date must be in the future.',
  InvalidSerialNumber:     'Serial number cannot be empty.',
  InvalidProductType:      'Invalid product type selected.',
  InvalidUnit:             'Invalid unit selected.',
  InvalidQuantity:         'Quantity must be greater than zero.',
  InvalidOrigin:           'Origin cannot be empty.',
  CannotCertifyInStatus:   'This batch cannot be certified in its current status.',
}

export function parseContractError(err) {
  // Try to decode the raw 4-byte selector from MetaMask's RPC error
  const selector = err?.data?.data ?? err?.data
  if (typeof selector === 'string' && selector.startsWith('0x')) {
    try {
      const decoded = iface.parseError(selector)
      if (decoded?.name && ERROR_MESSAGES[decoded.name]) {
        return ERROR_MESSAGES[decoded.name]
      }
    } catch {}
  }

  // Fallback: ethers v6 decoded error (non-MetaMask path)
  const name = err?.revert?.name ?? err?.reason
  return ERROR_MESSAGES[name] ?? err?.shortMessage ?? err?.message ?? 'Transaction failed.'
}
