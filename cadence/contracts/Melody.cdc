import MelodyError from "./MelodyError.cdc"
import FungibleToken from "./standard/FungibleToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import MetadataViews from "./standard/MetadataViews.cdc"
import MelodyTicket from "./MelodyTicket.cdc"


pub contract Melody {

    /**    ___  ____ ___ _  _ ____
       *   |__] |__|  |  |__| [__
        *  |    |  |  |  |  | ___]
         *************************/

    
    pub let UserCertificateStoragePath: StoragePath
    pub let UserCertificatePrivatePath: PrivatePath
    // pub let CollectionStoragePath: StoragePath
    // pub let CollectionPublicPath: PublicPath
    // pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /**    ____ _  _ ____ _  _ ___ ____
       *   |___ |  | |___ |\ |  |  [__
        *  |___  \/  |___ | \|  |  ___]
         ******************************/

    pub event ContractInitialized()
    pub event PauseStateChanged(pauseFlag: Bool, operator: Address)



    /**    ____ ___ ____ ___ ____
       *   [__   |  |__|  |  |___
        *  ___]  |  |  |  |  |___
         ************************/

     // ticket type
    pub enum PaymentType: UInt8 {
        pub case STREAM  // stream ticke 
        pub case REVOCABLE_STREAM // revocable stream ticket
        pub case VESTING
        pub case REVOCABLE_VESTING // revocable vesting ticket
    }

    // status for payment life cycle
    pub enum PaymentStatus: UInt8 {
        pub case UPCOMING  // not start yet 
        pub case ACTIVE // running payment
        pub case COMPLETE // completed payment
        pub case CANCELED // revoced payment
    }

    pub var totalCreated: UInt64
    pub var vestingCount: UInt64
    pub var streamCount: UInt64
    
   
    // global pause: true will stop pool creation
    pub var pause: Bool

    pub var melodyCommission: UFix64

    pub var minimumPayment: UFix64

    pub var graceDuration: UFix64

    // records user unclaim tickets with payments
    access(account) var userTicketRecords: {Address: [UInt64]}
    access(account) var paymentsRecords: {Address: [UInt64]}

    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}




    /**    ____ _  _ _  _ ____ ___ _ ____ _  _ ____ _    _ ___ _   _
       *   |___ |  | |\ | |     |  | |  | |\ | |__| |    |  |   \_/
        *  |    |__| | \| |___  |  | |__| | \| |  | |___ |  |    |
         ***********************************************************/

    
    pub resource interface IdentityCertificate {}

    pub resource UserCertificate: IdentityCertificate{ 

    }

    pub resource Payment {

        pub let id: UInt64
        pub var desc: String
        pub let creator: Address
        pub let config: {String: AnyStruct}
        pub let type: PaymentType
        pub let vault: @FungibleToken.Vault
        pub var ticket: @MelodyTicket.NFT?
        pub var withdrawn: UFix64
        pub var status: PaymentStatus


        pub var metadata: {String: AnyStruct}
        

        init(id: UInt64, desc: String, creator: Address, type: PaymentType, vault: @FungibleToken.Vault, config: {String: AnyStruct}) {
            self.id = id
            self.desc = desc
            self.creator = creator
            self.config = config
            self.type = type
            self.vault <- vault
            self.ticket <- nil
            self.withdrawn = 0.0
            self.status = PaymentStatus.UPCOMING
            self.metadata = {}
        }

        // query payment revocable
        pub fun getRevocable (): Bool {
            return self.type == Melody.PaymentType.REVOCABLE_STREAM || self.type == Melody.PaymentType.REVOCABLE_VESTING
        }
        // query balance
        pub fun queryBalance(): UFix64 {
            return self.vault.balance
        }

        // query metadata
        pub fun getInfo(): {String: AnyStruct} {
            // todo
            let metadata: {String: AnyStruct} = {}
            metadata["balance"] = self.vault.balance
            metadata["withdrawn"] = self.withdrawn
            metadata["type"] = self.type.rawValue // todo
            metadata["status"] = self.status.rawValue
            metadata["claimed"] = self.ticket == nil
            metadata["config"] = self.config

            let nftMetadata = MelodyTicket.getMetadata(self.id)!
            if nftMetadata != nil {
                metadata["recipient"] = (nftMetadata["owner"] as? Address)
            }
            metadata["ticketInfo"] = nftMetadata
            return metadata
        }

        

        // === write funcs ===
        // rrevoke payment
        pub fun revokePayment(userCertificateCap: Capability<&{Melody.IdentityCertificate}>): @FungibleToken.Vault {
            pre {
                self.status != PaymentStatus.COMPLETE && self.status != PaymentStatus.CANCELED : MelodyError.errorEncode(msg: "Cannot cancel close payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE)
                self.creator == userCertificateCap.borrow()!.owner!.address : MelodyError.errorEncode(msg: "Only owner can revokePayment", err: MelodyError.ErrorCode.ACCESS_DENIED)
                self.type == PaymentType.REVOCABLE_STREAM || self.type == Melody.PaymentType.REVOCABLE_VESTING : MelodyError.errorEncode(msg: "Only revocable payment can be revoked", err: MelodyError.ErrorCode.PAYMENT_NOT_REVOKABLE)
            }

            let balance = self.vault.balance
            self.status = PaymentStatus.CANCELED
            Melody.updateTicketMetadata(id: self.id, key: "status", value: PaymentStatus.CANCELED)
            
            return <- self.vault.withdraw(amount: balance)
        }

        // cache ticket while receiver do not have receievr resource
        access(contract) fun chacheTicket(ticket: @MelodyTicket.NFT) {
            pre {
                self.ticket == nil : MelodyError.errorEncode(msg: "Ticket already cached", err: MelodyError.ErrorCode.ALREADY_EXIST)
            }
            self.ticket <-! ticket
                    
            // emit event todo
        }

        // cache ticket while receiver do not have receievr resource
        access(contract) fun claimTicket():@MelodyTicket.NFT {
            pre {
                self.ticket != nil : MelodyError.errorEncode(msg: "Ticket already cached", err: MelodyError.ErrorCode.ALREADY_EXIST)
            }
            let ticket <- self.ticket <- nil
            self.config.remove(key: "receiver")
            return <- ticket!
        }

        // cache ticket while receiver do not have receievr resource
        access(contract) fun updateConfig(_ key: String, value: AnyStruct) {
            pre {
                self.config[key] != nil : MelodyError.errorEncode(msg: "Not set vaule", err: MelodyError.ErrorCode.NOT_EXIST)
            }
            self.config[key] = value
        }

        // cache ticket while receiver do not have receievr resource
        access(contract) fun changeRevokable() {

            var type = self.type

            if type == PaymentType.REVOCABLE_STREAM {
                type = PaymentType.STREAM
            } else if type == PaymentType.REVOCABLE_VESTING {
                type = PaymentType.VESTING
            } 

            // emit event todo
        }


        // withdraw
        access(contract) fun withdraw(_ amount: UFix64): @FungibleToken.Vault {
            pre {
                self.status != PaymentStatus.COMPLETE && self.status != PaymentStatus.CANCELED : MelodyError.errorEncode(msg: "Cannot update close payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE)
            }
            let currentTimestamp = getCurrentBlock().timestamp
            let startTimestamp = (self.config["startTimestamp"] as? UFix64)!
            let endTimestamp = (self.config["endTimestamp"] as? UFix64)!
            // update status when stream start
            if self.type == PaymentType.STREAM || self.type == PaymentType.REVOCABLE_STREAM {
                if self.status == PaymentStatus.UPCOMING && currentTimestamp >= startTimestamp {
                    self.status = PaymentStatus.ACTIVE
                }
                if self.status == PaymentStatus.ACTIVE && currentTimestamp >= endTimestamp {
                    self.status = PaymentStatus.COMPLETE
                }
            } else { // update vesing status
                if self.status == PaymentStatus.UPCOMING && currentTimestamp >= startTimestamp {
                    self.status = PaymentStatus.ACTIVE
                }
                let startTimestamp = (self.config["startTimestamp"] as? UFix64)!
                let stepDuration = (self.config["stepDuration"] as? UFix64)!
                let steps = (self.config["steps"] as? Int8)!
                let cliffDuration = (self.config["cliffDuration"] as? UFix64) ?? 0.0
                let endVestingTimestamp = startTimestamp + cliffDuration + UFix64(steps) * stepDuration
                if self.status == PaymentStatus.ACTIVE && currentTimestamp >= endVestingTimestamp {
                    self.status = PaymentStatus.COMPLETE
                }
            }

            // todo vesting state change

            
            assert(self.status == PaymentStatus.ACTIVE, message:  MelodyError.errorEncode(msg: "Cannot withdraw from inactive payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
            // assert(self.getRevocable() == true, message: MelodyError.errorEncode(msg: "Cannot withdraw from non-revocable payment", err: MelodyError.ErrorCode.PAYMENT_NOT_REVOKABLE))
            self.withdrawn = self.withdrawn + amount
            // todo emit
            return <- self.vault.withdraw(amount: amount)
        }

        destroy (){
            pre {
                self.status == PaymentStatus.COMPLETE && self.status == PaymentStatus.CANCELED : MelodyError.errorEncode(msg: "Cannot destroy active payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE)
            }
            destroy self.vault
            destroy self.ticket
        }
    }


    // resources
    // melody admin resource for manage melody contract
    pub resource Admin {

        access(self) var vaults: @{String: FungibleToken.Vault}

        access(self) let payments: @{UInt64: Payment}

        init() {
            self.payments <- {}
            self.vaults <- {}
        }

        pub fun setPause(_ flag: Bool) {
            pre {
                Melody.pause != flag : MelodyError.errorEncode(msg: "Set pause state faild, the state is same", err: MelodyError.ErrorCode.SAME_BOOL_STATE)
            }
            Melody.pause = flag

            emit PauseStateChanged(pauseFlag: flag, operator: self.owner!.address)
        }

        pub fun setCommission(_ commission: UFix64) {
            Melody.melodyCommission = commission

            // todo emit event
        }

        pub fun setMinimumPayment(_ min: UFix64) {
          
            Melody.minimumPayment = min
            // todo emit event
        }

        pub fun setGraceDuration(_ duration: UFix64) {
          
            Melody.graceDuration = duration
            // todo emit event
        }
        

        pub fun getPayment(_ id: UInt64): &Payment {
            pre{
                self.payments[id] != nil : MelodyError.errorEncode(msg: "Payment not found", err: MelodyError.ErrorCode.NOT_EXIST)
            }
            let paymentRef = (&self.payments[id] as &Payment?)!
            return paymentRef
        }

        pub fun savePayment(_ payment: @Payment) {
            pre {
                self.payments[payment.id] != nil : MelodyError.errorEncode(msg: "Payment already exists", err: MelodyError.ErrorCode.ALREADY_EXIST)
            }
            self.payments[payment.id] <-! payment
        }


        pub fun setVault(_ vault: @FungibleToken.Vault) {
            let identifier = vault.getType().identifier
            assert(self.vaults[identifier] == nil, message: MelodyError.errorEncode(msg: "Vault already exists", err: MelodyError.ErrorCode.ALREADY_EXIST))
            self.vaults[identifier] <-! vault
            // todo emit event
        }

        pub fun deposit(_ vault: @FungibleToken.Vault) {
            let identifier = vault.getType().identifier
            // todo emit event
            if self.vaults[identifier] == nil {
                self.vaults[identifier] <-! vault
            } else {
                let vaultRef = (&self.vaults[identifier] as &FungibleToken.Vault?)!
                vaultRef.deposit(from: <- vault)
            }

        }

        pub fun withdraw(_ key: String?, amount: UFix64?): @{String: FungibleToken.Vault} {
            let vaults: @{String:FungibleToken.Vault} <- {}
            var keys: [String] = []
            if key != nil {
                let vaultRef = (&vaults[key!] as &FungibleToken.Vault?)!
                let withdrawAmount = amount ?? vaultRef.balance
                vaults[key!] <-! vaultRef!.withdraw(amount: withdrawAmount)
                return <- vaults
            } else {
                keys = self.vaults.keys
                for k in keys {
                    let vaultRef = (&vaults[k] as &FungibleToken.Vault?)!
                    let withdrawAmount = amount ?? vaultRef.balance
                    vaults[k] <-! vaultRef!.withdraw(amount: withdrawAmount)
                }
                return <- vaults
            }
        }
       
        


        destroy() {
            destroy self.payments
            destroy self.vaults
        }
        
    }

   
    // ---- contract methods ----

    pub fun setupUser(): @UserCertificate {
        let certificate <- create UserCertificate()
        return <- certificate
    }

    // update nft metadata
    access(account) fun updateTicketMetadata(id: UInt64, key: String, value: AnyStruct) {
        pre {
            MelodyTicket.getMetadata(id) != nil : MelodyError.errorEncode(msg: "Ticket not found", err: MelodyError.ErrorCode.NOT_EXIST)
        }
        MelodyTicket.updateMetadata(id: id, key: key, value: value)
    }

    // set metadata
    access(account) fun setTicketMetadata(id: UInt64, metadata: {String: AnyStruct}) {
        pre {
            MelodyTicket.getMetadata(id) != nil : MelodyError.errorEncode(msg: "Ticket not found", err: MelodyError.ErrorCode.NOT_EXIST)
        }
        MelodyTicket.setMetadata(id: id, metadata: metadata)
    }

    // set payments records
    access(account) fun updatePaymentsRecords(address: Address, id: UInt64) {
        let ids = self.paymentsRecords[address] ?? []
        ids.append(id)
        self.paymentsRecords[address] = ids
    }


    /// create stream 
    /**
     ** @param userCertificateCap - creator cap to proof there identity
     ** @param vault - contain the FT token to steam
     ** @param reciever - the reciever address
     ** @param revocable - stream can be revoke or not
     ** @param config - config of create a stream
        ** @param startTimeStamp - start time of stream
        ** @param endTimeStamp - end time of stream
        ** @param desc - desc of stream
     */
    pub fun createStream(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, vault: @FungibleToken.Vault, reciever: Address, revocable: Bool, config: {String: AnyStruct}) {
        pre {
            vault.balance >= Melody.minimumPayment : MelodyError.errorEncode(msg: "Vault balance must be greater than ".concat(Melody.minimumPayment.toString()), err: MelodyError.ErrorCode.INVALID_PARAMETERS)
            self.pause == false: MelodyError.errorEncode(msg: "Create stream is paused", err: MelodyError.ErrorCode.PAUSED)
        }
        let account = self.account
        let adminRef = account.borrow<&Admin>(from: self.AdminStoragePath)!
        let creator = userCertificateCap.borrow()!.owner!.address
        let paymentId = Melody.totalCreated + UInt64(1)
        Melody.streamCount = Melody.streamCount + UInt64(1)
        
        let desc = (config["desc"] as? String) ?? ""
        var type = PaymentType.STREAM
        if revocable {
            type = PaymentType.REVOCABLE_STREAM
        }

        let recipient = getAccount(reciever).getCapability<&{NonFungibleToken.CollectionPublic}>(MelodyTicket.CollectionPublicPath)

        // todo validate config
        let currentTimestamp = getCurrentBlock().timestamp
        let startTimestamp = (config["startTimestamp"] as? UFix64)!
        let endTimestamp = (config["endTimestamp"] as? UFix64)!
        let transferable = (config["transferable"] as? Bool) ?? true

        assert(currentTimestamp + Melody.graceDuration < startTimestamp, message: MelodyError.errorEncode(msg: "Start time must be greater than current time", err: MelodyError.ErrorCode.INVALID_PARAMETERS))
        assert(endTimestamp > startTimestamp + Melody.graceDuration, message: MelodyError.errorEncode(msg: "End time must be greater than current time", err: MelodyError.ErrorCode.INVALID_PARAMETERS))

        if recipient == nil {
           config["reciever"] = reciever
        }

        let payment <- create Payment(id: paymentId, desc:desc, creator: creator, type: type, vault: <- vault, config: config)
       
        adminRef.savePayment(<- payment)

        self.totalCreated = paymentId
        self.streamCount = self.streamCount + UInt64(1)
        self.updatePaymentsRecords(address: creator, id: paymentId)

        let ticketMinter = account.borrow<&MelodyTicket.NFTMinter>(from: MelodyTicket.MinterStoragePath)!
       

        let name = "Melody".concat(" stream ticket#").concat(paymentId.toString())
        // todo
        let metadata: {String: AnyStruct} = {}
        metadata["paymentInfo"] = config
        metadata["paymentType"] = type
        metadata["paymentId"] = paymentId
        metadata["status"] = PaymentStatus.UPCOMING
        if transferable == false {
            metadata["transferable"] = false
        }
        
        let nft <- ticketMinter.mintNFT(name: name, description: desc, metadata: {})

        self.setTicketMetadata(id: nft.id, metadata: metadata)

        let paymentRef = adminRef.getPayment(paymentId)
        if recipient != nil {
            recipient.borrow()!.deposit(token: <- nft)
        } else {
            paymentRef.chacheTicket(ticket: <- nft)
            self.updateUserTicketsRecord(address: reciever, id:paymentRef.id, isDelete: false )
        }
        // emit event todo

    }

     /// create vesting
    pub fun createVesting(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, vault: @FungibleToken.Vault, reciever: Address, revocable: Bool, config: {String: AnyStruct}) {
        pre {
            vault.balance > Melody.minimumPayment : MelodyError.errorEncode(msg: "Vault balance must be greater than 0", err: MelodyError.ErrorCode.CAN_NOT_BE_ZERO)
            self.pause == false: MelodyError.errorEncode(msg: "Create stream is paused", err: MelodyError.ErrorCode.PAUSED)
        }
        let account = self.account
        let adminRef = account.borrow<&Admin>(from: self.AdminStoragePath)!
        let creator = userCertificateCap.borrow()!.owner!.address
        let paymentId = Melody.totalCreated + UInt64(1)
        Melody.vestingCount = Melody.vestingCount + UInt64(1)
        
        let desc = (config["desc"] as? String) ?? ""
        var type = Melody.PaymentType.VESTING
        if revocable {
            type = PaymentType.REVOCABLE_VESTING
        }

        let recipient = getAccount(reciever).getCapability<&{NonFungibleToken.CollectionPublic}>(MelodyTicket.CollectionPublicPath)

        // validate config
        let balance = vault.balance
        let currentTimestamp = getCurrentBlock().timestamp
        let startTimestamp = (config["startTimestamp"] as? UFix64)!
        let cliffDuration = (config["cliffDuration"] as? UFix64) ?? 0.0
        let cliffAmount = (config["cliffAmount"] as? UFix64) ?? 0.0
        let stepDuration = (config["stepDuration"] as? UFix64)!
        let steps = (config["steps"] as? Int8)!
        let stepAmount = (config["stepAmount"] as? UFix64)!
        let transferable = (config["transferable"] as? Bool) ?? true
        assert(steps >= 1, message: MelodyError.errorEncode(msg: "Step must greater than 0", err: MelodyError.ErrorCode.INVALID_PARAMETERS))

        let totalAmount = cliffAmount + UFix64(steps) * stepAmount

        assert(cliffAmount > 0.0 && cliffDuration > startTimestamp, message: MelodyError.errorEncode(msg: "Cliff amount and duration invalid", err: MelodyError.ErrorCode.INVALID_PARAMETERS))
        assert(cliffAmount > 0.0 && cliffDuration > 0.0, message: MelodyError.errorEncode(msg: "Start time must be greater than current time", err: MelodyError.ErrorCode.INVALID_PARAMETERS))
        assert(balance >= totalAmount, message: MelodyError.errorEncode(msg: "Valut balance not enougth - balance: ".concat(balance.toString()).concat("required: ").concat(totalAmount.toString()), err: MelodyError.ErrorCode.INVALID_PARAMETERS))
        assert(currentTimestamp + Melody.graceDuration < startTimestamp, message: MelodyError.errorEncode(msg: "Start time must be greater than current time with grace period", err: MelodyError.ErrorCode.INVALID_PARAMETERS))

        if recipient == nil {
           config["reciever"] = reciever
        }

        let payment <- create Payment(id: paymentId, desc:desc, creator: creator, type: type, vault: <- vault, config: config)
       
        adminRef.savePayment(<- payment)

        self.totalCreated = paymentId
        self.streamCount = self.streamCount + UInt64(1)
        self.updatePaymentsRecords(address: creator, id: paymentId)

        let ticketMinter = account.borrow<&MelodyTicket.NFTMinter>(from: MelodyTicket.MinterStoragePath)!

        let name = "Melody".concat("vesting ticket#").concat(paymentId.toString())

        let metadata:{String: AnyStruct} = {}
        metadata["paymentInfo"] = config
        metadata["paymentType"] = type
        metadata["paymentId"] = paymentId
        metadata["status"] = PaymentStatus.UPCOMING
        if transferable == false {
            metadata["transferable"] = false
        }

        let nft <- ticketMinter.mintNFT(name: name, description: desc, metadata: {})

        self.setTicketMetadata(id: nft.id, metadata: metadata)

        let paymentRef = adminRef.getPayment(paymentId)
        if recipient != nil {
            recipient.borrow()!.deposit(token: <- nft)
        } else {
            paymentRef.chacheTicket(ticket: <- nft)
            self.updateUserTicketsRecord(address: reciever, id:paymentRef.id, isDelete: false )
        }
        // emit event todo

    }

    // todo update
    // pub fun updatePayment(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, paymentId: UInt64, config: {String: AnyStruct}) {
    //     pre {
    //         self.paymentsRecords[userCertificateCap.borrow()!.owner!.address]!.contains(paymentId): MelodyError.errorEncode(msg: "Access denied when update payment info", err: MelodyError.ErrorCode.ACCESS_DENIED)
    //     }

    //     let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(paymentId)
    //     let config = paymentRef.config
    //     // todo make sure modify 
    //     if paymentRef.status == PaymentStatus.UPCOMING {
    //         let desc = (config["desc"] as? String)
    //         if desc != nil {
    //             paymentRef.updateConfig("desc", value: desc)
    //         }
    //     }

        
        
    // }

    // change payment revokable to non-revokable
    pub fun changeRevokable(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, paymentId: UInt64) {
        pre {
            self.paymentsRecords[userCertificateCap.borrow()!.owner!.address]!.contains(paymentId): MelodyError.errorEncode(msg: "Access denied when update payment info", err: MelodyError.ErrorCode.ACCESS_DENIED)

        }
        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(paymentId)

        assert(paymentRef.status != PaymentStatus.CANCELED || paymentRef.status != PaymentStatus.COMPLETE , message: MelodyError.errorEncode(msg: "Cannot change revokable with canceled payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        assert(paymentRef.type != PaymentType.VESTING && paymentRef.type != PaymentType.STREAM, message: MelodyError.errorEncode(msg: "Cannot change revokable with non-revoked payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        paymentRef.changeRevokable()
    }


    // change payment ticket transferable if is non-transferable
    pub fun changeTransferable(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, paymentId: UInt64) {
        pre {
            self.paymentsRecords[userCertificateCap.borrow()!.owner!.address]!.contains(paymentId): MelodyError.errorEncode(msg: "Access denied when update payment info", err: MelodyError.ErrorCode.ACCESS_DENIED)
        }
        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(paymentId)
        let transferable = paymentRef.config["transferable"] as? Bool ?? true
        assert(paymentRef.status != PaymentStatus.CANCELED || paymentRef.status != PaymentStatus.COMPLETE , message: MelodyError.errorEncode(msg: "Cannot change transferable with canceled payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        assert(transferable == false, message: MelodyError.errorEncode(msg: "Only allow no-transferable to transferable", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        paymentRef.updateConfig("transferable", value: true)
        Melody.updateTicketMetadata(id: paymentId, key: "transferable", value: true)

    }

    pub fun claimTicket(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, paymentId: UInt64): @MelodyTicket.NFT {
        pre {
            self.getUserTicketRecords(userCertificateCap.borrow()!.owner!.address)!.contains(paymentId): MelodyError.errorEncode(msg: "Access denied when claim ticket", err: MelodyError.ErrorCode.ACCESS_DENIED)
        }
        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(paymentId)
        assert(paymentRef.status != PaymentStatus.CANCELED, message: MelodyError.errorEncode(msg: "Cannot claim ticket from canceled payment", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        let config = paymentRef.config
        let recipient = (config["reciever"] as? Address)!
        assert(recipient == userCertificateCap.borrow()!.owner!.address, message: MelodyError.errorEncode(msg: "Cannot claim ticket from wrong receiver", err: MelodyError.ErrorCode.ACCESS_DENIED))
        

        self.updateUserTicketsRecord(address: recipient, id:paymentRef.id, isDelete: true )

        return <- paymentRef.claimTicket()
    }


    pub fun withdraw(userCertificateCap: Capability<&{Melody.IdentityCertificate}>, ticket: &MelodyTicket.NFT): @FungibleToken.Vault {
        pre {
            userCertificateCap.borrow()!.owner!.address == ticket.owner!.address : MelodyError.errorEncode(msg: "Withdraw ", err: MelodyError.ErrorCode.ACCESS_DENIED)
        }
        // todo
        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(ticket.id)

        var vault: @FungibleToken.Vault? <- nil

        if paymentRef.type == PaymentType.VESTING || paymentRef.type == PaymentType.REVOCABLE_VESTING {
            vault <-! self.withdrawVesting(ticket: ticket)
        } else {
            vault <-! self.withdrawStream(ticket: ticket)
        }

        return <- vault!
    }

    // stream withdraw
    access(contract) fun withdrawStream(ticket: &MelodyTicket.NFT): @FungibleToken.Vault {

        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(ticket.id)
        let paymentType = paymentRef.type
        let paymentStatus = paymentRef.status
        let config = paymentRef.config
        let vaultRef = &paymentRef.vault as! &FungibleToken.Vault
        let withdrawn = paymentRef.withdrawn

        assert(paymentType == PaymentType.STREAM || paymentType == PaymentType.REVOCABLE_STREAM, message: MelodyError.errorEncode(msg: "Can only withdraw from stream payment", err: MelodyError.ErrorCode.TYPE_MISMATCH))
        assert(paymentStatus == PaymentStatus.UPCOMING || paymentStatus == PaymentStatus.ACTIVE, message: MelodyError.errorEncode(msg: "Can withdraw with wrong status", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        
        let currentTimestamp = getCurrentBlock().timestamp

        let startTimeStamp = (config["startTimeStamp"] as? UFix64)!
        let endTimeStamp = (config["endTimeStamp"] as? UFix64)!
        let vaultBalance = vaultRef.balance

        assert(currentTimestamp > startTimeStamp, message: MelodyError.errorEncode(msg: "Can withdraw before start", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        var timeDelta = currentTimestamp - startTimeStamp
        if currentTimestamp > endTimeStamp {
            timeDelta = endTimeStamp - startTimeStamp
        }
        let streamed = timeDelta / (endTimeStamp - startTimeStamp) * (vaultBalance + withdrawn)
        let withdrawnAmount = streamed - withdrawn
        assert(streamed >= withdrawn, message: MelodyError.errorEncode(msg: "Steamed amount must greater than withdraw amount", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        let withdrawVault <- paymentRef.withdraw(withdrawnAmount)

        // commision cut
        self.cutCommision(&withdrawVault as &FungibleToken.Vault)
        // todo emit event

        return <- withdrawVault
    }
    
    // vesting withdraw
    access(contract) fun withdrawVesting(ticket: &MelodyTicket.NFT): @FungibleToken.Vault {
        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(ticket.id)
        let paymentType = paymentRef.type
        let paymentStatus = paymentRef.status
        let config = paymentRef.config
        let vaultRef = &paymentRef.vault as! &FungibleToken.Vault
        let withdrawn = paymentRef.withdrawn

        assert(paymentType == PaymentType.VESTING || paymentType == PaymentType.REVOCABLE_VESTING, message: MelodyError.errorEncode(msg: "Can only withdraw from vesting payment", err: MelodyError.ErrorCode.TYPE_MISMATCH))
        assert(paymentStatus == PaymentStatus.UPCOMING || paymentStatus == PaymentStatus.ACTIVE, message: MelodyError.errorEncode(msg: "Can withdraw with wrong status", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        
        let currentTimestamp = getCurrentBlock().timestamp

        let startTimeStamp = (config["startTimeStamp"] as? UFix64)!
        let cliffDuration = (config["cliffDuration"] as? UFix64) ?? 0.0
        let cliffAmount = (config["cliffAmount"] as? UFix64) ?? 0.0
        let stepDuration = (config["stepDuration"] as? UFix64)!
        let steps = (config["steps"] as? Int8)!
        let stepAmount = (config["stepAmount"] as? UFix64)!
        let transferable = (config["transferable"] as? Bool) ?? true
        let vaultBalance = vaultRef.balance
        let timeAfterCliff = startTimeStamp + cliffDuration
        let passedSinceCliff = currentTimestamp - timeAfterCliff

        var stepPassed = Int8(passedSinceCliff / stepDuration)
        if stepPassed >= steps {
            stepPassed = steps
        }

        assert(currentTimestamp > startTimeStamp, message: MelodyError.errorEncode(msg: "Can withdraw before start", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        var timeDelta = currentTimestamp - startTimeStamp

        var claimable = 0.0

        if cliffDuration <= timeDelta {
            claimable = cliffAmount + claimable
        } 

        claimable = claimable + (UFix64(stepPassed) * stepAmount)
        let canClaimAmount = claimable - withdrawn
        assert(claimable >= withdrawn, message: MelodyError.errorEncode(msg: "Vesting claimable amount must greater than withdraw amount", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        assert(canClaimAmount > 0.0, message: MelodyError.errorEncode(msg: "No amount can claim", err: MelodyError.ErrorCode.CAN_NOT_BE_ZERO))

        let withdrawVault <- paymentRef.withdraw(canClaimAmount)

        // commision cut
        self.cutCommision(&withdrawVault as &FungibleToken.Vault)
        // todo emit event

        return <- withdrawVault
    }


    access(contract) fun cutCommision(_ vaultRef: &FungibleToken.Vault){
        if self.melodyCommission > 0.0 {
            let adminRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!
            let commisionAmount = vaultRef.balance * self.melodyCommission
            adminRef.deposit(<- vaultRef.withdraw(amount: commisionAmount))
            // todo emit event
        }
    }

    access(contract) fun updateUserTicketsRecord(address: Address, id: UInt64, isDelete: Bool){
        pre{
                isDelete == true && Melody.userTicketRecords[address]!.contains(id) : MelodyError.errorEncode(msg: "Delete failed: record not existed", err: MelodyError.ErrorCode.INVALID_PARAMETERS)
                isDelete == false && Melody.userTicketRecords[address]!.contains(id) == false: MelodyError.errorEncode(msg: "Add failed: record already existed", err: MelodyError.ErrorCode.ALREADY_EXIST)
        }
        let userTicketRecords = Melody.userTicketRecords[address] ?? []
        if isDelete {
            let index = userTicketRecords.firstIndex(of: id)!
            userTicketRecords.remove(at: index)

        } else {
            userTicketRecords.append(id)
        }

        Melody.userTicketRecords[address] = userTicketRecords

        // todo emit event

    }


    pub fun getPaymentsIdRecords(_ address: Address): [UInt64] {
        let ids = self.paymentsRecords[address] ?? []
        return ids
    }

    pub fun getPaymentInfo(_ id: UInt64): {String: AnyStruct} {
        var info: {String: AnyStruct}  = {}
        let paymentRef = self.account.borrow<&Admin>(from: self.AdminStoragePath)!.getPayment(id)

        info = paymentRef.getInfo()

        return info
    }

    pub fun getUserTicketRecords(_ address: Address): [UInt64] {
        let ids = self.userTicketRecords[address] ?? []
        return ids
    }
    


    // ---- init func ----
    init() {
        self.UserCertificateStoragePath = /storage/melodyUserCertificate
        self.UserCertificatePrivatePath = /private/melodyUserCertificate
        self._reservedFields = {}
        self.totalCreated = 0
        self.vestingCount = 0
        self.streamCount = 0
        self.pause = false

        // for store the unclaim ticket for users
        self.userTicketRecords = {}
        self.paymentsRecords = {}

        self.melodyCommission = 0.01

        self.minimumPayment = 0.1

        self.graceDuration = 300.0

        self.AdminStoragePath = /storage/MelodyAdmin

        let account = self.account
        let admin <- create Admin()
        account.save(<- admin, to: self.AdminStoragePath)

        account.save(<- create UserCertificate(), to: self.UserCertificateStoragePath)
    }

}