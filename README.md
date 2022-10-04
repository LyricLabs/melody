# Melody —— a streaming/vesting payment with NFT receipt

# Project Name
Melody payment

Testnet contract (https://flow-view-source.com/testnet/account/0xb797a88390357df4)
## Description
Melody is a tool that helps DAO and individuals to derive a transferable and tradable note with periodical and streaming payment as underlying value. The note is created in the form of NFT.

### Problem statement

We see value exchanges increasingly take place on blockchain on our way towards the Web3 world, but unfortunately without adequate transparency and agility of blockchain payment, such value exchange behaviors are highly dependent on the trust between the partners or a third-party custody, both in quite centralized ways. 
However, with fully functioning up the potential of smart contract, the interactions between both sides of payment should be able to get more decentralized and trustless.

Melody is designed to cater to such needs. The target audience of Melody are those who ask for streaming payment on blockchain - such as DAO organizers or project teams that pay their members or contributors in tokens in the way of streaming, as well as the investors of tokens with vesting periods who want to manage the risk and return more flexibly.
Luckily via smart contract, the above-mentioned periodical and streaming payment will be more transparent and predictable, and with the help of NFT, which could serve the role of ticket, payment distribution and portfolio management will be smarter.  


### Proposed solution
- Product Introduction
Via publicly establishing Payment (Streaming/Vesting) method of periodical payments for users, a Ticket will be issued to the receiver of the Payment. The Ticket is an NFT asset with features similar to asset-backed notes.

Creator of the Payment can authorize the NFT holder to transfer or trade it. For example, a token investor can transfer the risk of future vested allotments by trading the Vesting NFT before the allotments land, while a Salary account (the receiver) can also transfer the NFT that carries streaming payment rights. Thus, according to different demand scenarios, the Payment creator can deploy different types of NFTs/notes -  revocable or non-revocable Payment, transferable or non-transferable Payment.

With NFT syncing and storing all the payment information of the asset-backed note, the holder’s right (especially under the circumstance that the NFT is traded) can also be displayed and verified.

Technical architecture
The product ideation will be fully realized using Cadence, with the master smart contract of Melody managing Payment, while employing standard NFT contract as the contract of asset-backed note, which asks Melody to serve as issuer to administer it.

Product logo
![](https://trello.com/1/cards/62dd12a167854020143ccd01/attachments/62f0c3e7b0401e250f0a5199/previews/62f0c3e7b0401e250f0a51df/download/melody-logo.png)

