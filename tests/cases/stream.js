import t from '@onflow/types'
import fcl from '@onflow/fcl'
import dotenv from 'dotenv'
import moment from 'moment'
import { accountAddr } from '../../config/constants.js'
import { test1Authz, test2Authz, test1Addr, test2Addr } from '../../utils/authz'
import { buildAndExecScript, fclInit, buildAndSendTrx, sleep } from '../../utils/index'
import { getBal, transferToken } from '../../scripts/helper.js'
let paymentId = 0
export const streamTestCases = () =>
  describe('Stream test cases', () => {
    beforeAll(() => {
      dotenv.config()
      return fclInit()
    })

    test('Revocable stream test', async () => {
      let res = await buildAndSendTrx('setGraceDuration', [fcl.arg('0.0', t.UFix64)])
      expect(res).not.toBeNull()
      expect(res.status).toBe(4)
      let currentTimestamp = await buildAndExecScript('getTimestamp')

      res = await buildAndSendTrx('createStream', [
        fcl.arg('fusdVault', t.String),
        fcl.arg('100.0', t.UFix64),
        fcl.arg(true, t.Bool),
        fcl.arg(false, t.Bool),
        fcl.arg(Number(currentTimestamp + 2).toFixed(2), t.UFix64),
        fcl.arg((Number(currentTimestamp) + 10).toFixed(2), t.UFix64),
        fcl.arg(test2Addr, t.Address),
      ])

      expect(res).not.toBeNull()
      expect(res.status).toBe(4)

      paymentId = 5

      res = await buildAndExecScript('getPaymentInfo', [fcl.arg(paymentId, t.UInt64)])
      expect(res).not.toBeNull()
      console.log(res, 'paymentInfo')

      await sleep(7000)

      res = await buildAndExecScript('getOutgoingPayment', [fcl.arg(accountAddr, t.Address)])
      expect(res).not.toBeNull()
      expect(res.length).toBe(5)
    })

    test('Test transfeable change', async () => {
      let res = await buildAndExecScript('getUserIncomePayment', [fcl.arg(test2Addr, t.Address)])
      expect(res).not.toBeNull()
      expect(res.length).toBe(1)
      expect(Number(res[0].id)).toBe(paymentId)

      res = await buildAndSendTrx(
        'transferTicket',
        [fcl.arg(paymentId, t.UInt64), fcl.arg(test1Addr, t.Address)],
        test2Authz(),
      )
      expect(res).toBeNull()

      res = await buildAndSendTrx('changeTransferable', [fcl.arg(paymentId, t.UInt64)])
      expect(res).not.toBeNull()
      expect(res.status).toBe(4)

      res = await buildAndExecScript('getPaymentInfo', [fcl.arg(paymentId, t.UInt64)])
      expect(res).not.toBeNull()
      console.log(res, 'paymentInfo')

      res = await buildAndSendTrx(
        'transferTicket',
        [fcl.arg(paymentId, t.UInt64), fcl.arg(test1Addr, t.Address)],
        test2Authz(),
      )
      expect(res).not.toBeNull()
      expect(res.status).toBe(4)
      
      res = await buildAndSendTrx('changeTransferable', [fcl.arg(paymentId, t.UInt64)])
      expect(res).toBeNull()


    })

    test('Test reovcable payment', async () => {
     
    })


  })
