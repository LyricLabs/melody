import t from '@onflow/types'
import fcl from '@onflow/fcl'
import dotenv from 'dotenv'
import moment from 'moment'
import { accountAddr } from '../../config/constants.js'
import { test1Authz, test2Authz, test1Addr, test2Addr } from '../../utils/authz'
import { buildAndExecScript, fclInit, buildAndSendTrx, sleep } from '../../utils/index'
import { getBal, transferToken } from '../../scripts/helper.js'

export const vestingTestCases = () =>
  describe('User test cases', () => {
    beforeAll(() => {
      dotenv.config()
      return fclInit()
    })

    test('init user certifcate', async () => {
      expect(null).toBeNull()
    })
  })
