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
  let currentTimestamp = await buildAndExecScript('getTimestamp')
  let res = await buildAndExecScript('getVestingCount')
  console.log(res, 'vesting count')
  // res = await buildAndSendTrx('createVesting', [
  //   fcl.arg('fusdVault', t.String),
  //   fcl.arg(true, t.Bool), // revocable
  //   fcl.arg(true, t.Bool), // transferable
  //   fcl.arg(test2Addr, t.Address), // receiver
  //   fcl.arg((Number(currentTimestamp) + 1000).toFixed(2), t.UFix64), // start time
  //   fcl.arg('0.0', t.UFix64), // cliff duration
  //   fcl.arg('0.0', t.UFix64), // cliff amount
  //   fcl.arg(3, t.Int8), // steps
  //   fcl.arg('2.0', t.UFix64), // step duration
  //   fcl.arg('30.0', t.UFix64), // step amount
  // ])

  // res = await buildAndSendTrx('createSimpleVesting', [
  //   fcl.arg('fusdVault', t.String),
  //   fcl.arg(true, t.Bool), // revocable
  //   fcl.arg(true, t.Bool), // transferable
  //   fcl.arg(test2Addr, t.Address), // receiver
  //   fcl.arg((Number(currentTimestamp) + 1000).toFixed(2), t.UFix64), // start time
  //   fcl.arg(3, t.Int8), // steps
  //   fcl.arg('2.0', t.UFix64), // step duration
  //   fcl.arg('30.0', t.UFix64), // step amount
  // ])

  // console.log(res)

  // res = await buildAndExecScript('getNFTMetadata', [fcl.arg(6, t.UInt64)])
  // console.log(res)
  res = await buildAndExecScript('getUserIncomePayment', [fcl.arg(test1Addr, t.Address)])

  console.log(res)

  res = await buildAndExecScript('getTicketMetadata', [
    fcl.arg(test2Addr, t.Address),
    fcl.arg(9, t.UInt64),
  ])

  console.log(JSON.stringify(res))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
