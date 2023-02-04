import t from '@onflow/types'
import { fclInit, buildAndExecScript, buildAndSendTrx } from '../utils/index.js'
import { accountAddr, FLOWTokenAddr } from '../config/constants.js'
import fcl from '@onflow/fcl'

const main = async () => {
  fclInit()
  let res = null

  res = await buildAndExecScript('checkInit', [fcl.arg(accountAddr, t.Address)])
  console.log(res)

  res = await buildAndSendTrx('setupAccount', [])
  console.log(res)

  res = await buildAndExecScript('checkInit', [fcl.arg(accountAddr, t.Address)])
  console.log(res)

  res = await buildAndExecScript('getPause')
  console.log(res)

  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
