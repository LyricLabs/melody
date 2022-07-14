import t from '@onflow/types'
import { fclInit, buildAndSendTrx, buildAndExecScript } from '../utils/index.js'
import fcl from '@onflow/fcl'
import { accountAddr, FLOWTokenAddr } from '../config/constants.js'
import { test1Addr, test2Addr, test1Authz, test2Authz } from '../utils/authz.js'

export const mintFlowToken = async (address, amount) => {
  await buildAndSendTrx('mintFlowToken', [fcl.arg(address, t.Address), fcl.arg(amount, t.UFix64)])
}

const main = async () => {
  // fcl init and load config
  fclInit()
  // mint token 50000

  // let mintRes = await buildAndSendTrx('mintPackage', [fcl.arg(accountAddr, t.Address)])
  // console.log(mintRes)

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
