# 🎨 EchoRoyale – Automated Royalty Distribution for Digital Art on Stacks

EchoRoyale is a Clarity smart contract designed to streamline **automated royalty distribution** for creators and contributors of digital art NFTs. It supports **primary sales**, **secondary market royalties**, and **collaborative works**, ensuring that every stakeholder gets their fair share—**even as artwork changes hands over time**.

> “Your art echoes in every sale. Let the royalties follow.”

---

## 🚀 Features

* **Artwork Registration**: Creators can register digital artworks with titles, descriptions, prices, and royalty rates.
* **Contributor Management**: Add collaborators (e.g., co-artists, musicians, developers) with individual revenue shares.
* **NFT Integration**: Link an NFT contract to each artwork for verifiable ownership and traceability.
* **Primary Sale Automation**: Automatically distributes STX proceeds among all contributors when an artwork is first sold.
* **Secondary Sale Royalties**: Captures resale royalties and allocates them proportionally to contributors.
* **Royalty Claims**: Contributors can claim accumulated royalties anytime.
* **Audit-Ready Records**: Tracks artwork metadata, sale history, and royalty distributions transparently.

---

## 🛠️ Built With

* **Clarity** – Smart contract language for the Stacks blockchain.
* **SIP-009** – NFT trait standard for consistent NFT interactions.
* **Stacks Blockchain** – For secure, decentralized execution and STX transfers.

---

## 📚 Function Overview

### 📄 Artwork & Contributor Management

| Function            | Description                                                |
| ------------------- | ---------------------------------------------------------- |
| `register-artwork`  | Registers new artwork and adds creator as 100% contributor |
| `add-contributor`   | Adds collaborators and reallocates creator's share         |
| `link-nft-contract` | Links an NFT contract to a registered artwork              |

### 💰 Sales & Royalties

| Function                | Description                                                      |
| ----------------------- | ---------------------------------------------------------------- |
| `primary-sale`          | Handles primary sale and splits proceeds among contributors      |
| `record-secondary-sale` | Records secondary sale, extracts royalties, and distributes them |
| `claim-royalties`       | Allows contributors to withdraw their accumulated royalties      |

### 🔍 Read-only Queries

| Function                  | Description                                     |
| ------------------------- | ----------------------------------------------- |
| `get-artwork-details`     | Fetch metadata about an artwork                 |
| `get-contributor-details` | View role and share percentage of a contributor |
| `get-claimable-royalties` | Check how much a contributor can claim          |

---

## 📦 Data Structures

### `artworks`

Stores metadata for each registered artwork:

* title, description, creator, price, royalty %, etc.

### `contributors`

Tracks each contributor's role and share (in per-mille, out of 1000)

### `secondary-sales`

Logs all secondary sales: seller, buyer, sale amount, royalty portion, and timestamp

### `claimable-royalties`

Holds unclaimed royalties per contributor, per artwork

---

## 🧪 Example Flow

1. **Artist A** registers artwork `#0` with 10% royalties.
2. They add **Contributor B** with 40% share.
3. Artwork is linked to an NFT contract.
4. A **primary sale** occurs → STX is distributed to A and B.
5. A **secondary sale** occurs → 10% royalty is collected and split.
6. Contributors can **claim** royalties at any time.

---

## ⚠️ Notes & Limitations

* Contributor distribution assumes a limited number of collaborators. Clarity does not support dynamic iteration over large maps.
* NFT transfer/ownership logic is mocked (`nft-get-owner?`). Replace with live `contract-call?` to your SIP-009 NFT contract.
* No support yet for revoking contributors or dynamically updating share splits after primary sale.
* Security review and testing required before production deployment.

---

## 🔐 Permissions & Access

| Action                | Permission                                       |
| --------------------- | ------------------------------------------------ |
| Register artwork      | Any principal                                    |
| Add contributors      | Only creator                                     |
| Link NFT contract     | Only creator                                     |
| Execute primary sale  | Any buyer                                        |
| Record secondary sale | Anyone (requires correct contract/token details) |
| Claim royalties       | Only contributor involved                        |

---

## 🧾 License

MIT License – Use it, fork it, extend it. Just don’t forget the artists.

---

## 💬 Inspiration

> The name **EchoRoyale** reflects the idea that art is not just sold once—it echoes through time and space, resold, appreciated, and remembered. And every echo deserves a reward.
