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
  BatchExpired:            'This batch has expired and cannot move forward.',
  CannotDistributeRecalled:'A recalled batch cannot be distributed.',
  BatchNotRecalled:        'This batch has not been recalled.',
}

export function parseContractError(err) {
  const name = err?.revert?.name ?? err?.reason
  return ERROR_MESSAGES[name] ?? err?.shortMessage ?? err?.message ?? 'Transaction failed.'
}
