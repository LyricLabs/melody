/* 
*
*  This is an example implementation of a Flow Non-Fungible Token
*  It is not part of the official standard but it assumed to be
*  similar to how many NFTs would implement the core functionality.
*
*  This contract does not implement any sophisticated classification
*  system for its NFTs. It defines a simple NFT with minimal metadata.
*   
*/

import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import MetadataViews from "./standard/MetadataViews.cdc"
import MelodyError from "./MelodyError.cdc"



pub contract MelodyTicket: NonFungibleToken {


    /**    ___  ____ ___ _  _ ____
       *   |__] |__|  |  |__| [__
        *  |    |  |  |  |  | ___]
         *************************/


    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath


    /**    ____ _  _ ____ _  _ ___ ____
       *   |___ |  | |___ |\ |  |  [__
        *  |___  \/  |___ | \|  |  ___]
         ******************************/

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event ModelUpgraded(modelId: UInt64, dnaId: UInt64, dnaType: UInt64, level: Int)
    pub event ModelExpanded(modelId: UInt64, dnaId: UInt64, dnaType: UInt64, slotNum: UInt64)


   
    /**    ____ ___ ____ ___ ____
       *   [__   |  |__|  |  |___
        *  ___]  |  |  |  |  |___
         ************************/

    pub var totalSupply: UInt64
    pub var baseURI: String

    // metadata 
    access(contract) var predefinedMetadata: {UInt64: {String: AnyStruct}}

    // Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}


    /**    ____ _  _ _  _ ____ ___ _ ____ _  _ ____ _    _ ___ _   _
       *   |___ |  | |\ | |     |  | |  | |\ | |__| |    |  |   \_/
        *  |    |__| | \| |___  |  | |__| | \| |  | |___ |  |    |
         ***********************************************************/
    

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let name: String
        pub let description: String
        pub let thumbnail: String

        access(self) let royalties: [MetadataViews.Royalty]
        access(self) let metadata: {String: AnyStruct}


    
        init(
            id: UInt64,
            name: String,
            description: String,
            metadata: {String: AnyStruct},
        ) {
            self.id = id
            self.name = name
            self.description = description
            if MelodyTicket.baseURI != "" {
                self.thumbnail = MelodyTicket.baseURI.concat(id.toString())
            } else {
                self.thumbnail = ""
            }
            self.royalties = [] // get from metadata
            self.metadata = metadata
        }

        destroy (){
            let metadata = self.getMetadata()
            let status = (metadata["status"] as? Int8)!
            assert(status > 1, message: MelodyError.errorEncode(msg: "Cannot destory ticket while it is activing", err: MelodyError.ErrorCode.WRONG_LIFE_CYCLE_STATE))
        }


        pub fun getMetadata(): {String: AnyStruct} {

            let metadata = MelodyTicket.predefinedMetadata[self.id] ?? {}
            // todo add upgradeinfo
            metadata["metadata"] = self.metadata
            return metadata
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Melody ticket NFT", number: self.id, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>(): // todo
                    return MetadataViews.ExternalURL("https://example-nft.onflow.org/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: MelodyTicket.CollectionStoragePath,
                        publicPath: MelodyTicket.CollectionPublicPath,
                        providerPath: /private/MelodyCollection,
                        publicCollection: Type<&MelodyTicket.Collection{MelodyTicket.CollectionPublic}>(),
                        publicLinkedType: Type<&MelodyTicket.Collection{MelodyTicket.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&MelodyTicket.Collection{MelodyTicket.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-MelodyTicket.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile( 
                            url: "" // todo
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Melody ticket NFT",
                        description: "This collection is Melody ticket NFT.",
                        externalURL: MetadataViews.ExternalURL(""), // todo
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url:"" // todo
                            ),
                            mediaType: "image/png"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: "" // todo
                            ),
                            mediaType: "image/png"
                        ),
                        socials: {
                            "twitter": MetadataViews.ExternalURL("") // todo
                        }
                    )
                case Type<MetadataViews.Traits>():

                    let metadata = MelodyTicket.predefinedMetadata[self.id]!

                    let traitsView = MetadataViews.dictToTraits(dict: metadata, excludedNames: [])

                    // mintedTime is a unix timestamp, we should mark it with a displayType so platforms know how to show it.
                    let mintedTimeTrait = MetadataViews.Trait(name: "mintedTime", value: self.metadata["mintedTime"]!, displayType: "Date", rarity: nil)
                    traitsView.addTrait(mintedTimeTrait)
                    
                    return traitsView

            }
            return nil
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    }

    pub resource interface CollectionPrivate {
        pub fun borrowMelodyTicket(id: UInt64): &MelodyTicket.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow MelodyTicket reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: CollectionPublic, CollectionPrivate, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            pre {
                // transferable
            }
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {

            let id: UInt64 = token.id
            let metadata = MelodyTicket.getMetadata(id)!
            
            let transferable = metadata["transferable"] as? Bool ?? true

            assert(transferable == true, message: MelodyError.errorEncode(msg: "Ticket is not transferable", err: MelodyError.ErrorCode.NOT_TRANSFERABLE))

            let token <- token as! @MelodyTicket.NFT

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowMelodyTicket(id: UInt64): &MelodyTicket.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &MelodyTicket.NFT
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let MelodyTicket = nft as! &MelodyTicket.NFT
            return MelodyTicket as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            name: String,
            description: String,
            metadata: {String: AnyStruct}
        ): @MelodyTicket.NFT {
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp

            let nftId = MelodyTicket.totalSupply + UInt64(1)
            // create a new NFT
            var newNFT <- create NFT(
                id: nftId,
                name: name,
                description: description,
                metadata: metadata,
            )
            // deposit it in the recipient's account using their reference
            // recipient.deposit(token: <- newNFT)

            MelodyTicket.totalSupply = nftId
            return <- newNFT
        }
        

     
        // UpdateMetadata
        // Update metadata for a typeId
        //  type // max // name // description // thumbnail // royalties
        //
        pub fun updateMetadata(id: UInt64, metadata: {String: AnyStruct}) {
            MelodyTicket.predefinedMetadata[id] = metadata
        }

        pub fun setBaseURI(_ uri: String) {
            MelodyTicket.baseURI = uri
        }
    }


    access(contract) fun updateMetadata(id: UInt64, metadata: {String: AnyStruct}) {
        MelodyTicket.predefinedMetadata[id] = metadata
    }

    // public funcs

    pub fun getTotalSupply(): UInt64 {
        return MelodyTicket.totalSupply
    }

    pub fun getMetadata(_ id: UInt64): {String: AnyStruct}? {
        return MelodyTicket.predefinedMetadata[id]
    }




    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/MelodyTicketCollection
        self.CollectionPublicPath = /public/MelodyTicketCollection
        // self.CollectionPrivatePath = /private/MelodyTicketCollection
        self.MinterStoragePath = /storage/MelodyTicketMinter
        self._reservedFields = {}

        self.predefinedMetadata = {}
        self.baseURI = ""

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&MelodyTicket.Collection{NonFungibleToken.CollectionPublic, MelodyTicket.CollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )



        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<- minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 