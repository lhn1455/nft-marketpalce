// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * ReentrancyGuard : 재진입공격에 대한 방어
 */
contract Marketplace is ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private _nftsSold; //sold된 nft의 수량 (sold시 +1 / relisted시 -1)
  Counters.Counter private _nftCount; //listed된 nft의 수량
  uint256 public LISTING_FEE = 0.0001 ether; //seller로 부터 얻는 수익 & nft가 팔릴때 marketplace contract owner에게  전송
  address payable private _marketOwner; // marketplace owner & nft listing fee를 받는 계정
  mapping(uint256 => NFT) private _idToNFT; // tokenId to struct(NFT)

  struct NFT { // marketplace에 list된 nft의 정보
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool listed;
  }
  event NFTListed(
    address nftContract,
    uint256 tokenId,
    address seller,
    address owner,
    uint256 price
  );
  event NFTSold(
    address nftContract,
    uint256 tokenId,
    address seller,
    address owner,
    uint256 price
  );

  constructor() {
    _marketOwner = payable(msg.sender);
  }

  // List the NFT on the marketplace
  function listNft(address _nftContract, uint256 _tokenId, uint256 _price) public payable nonReentrant {
    require(_price > 0, "Price must be at least 1 wei");
    require(msg.value == LISTING_FEE, "Not enough ether for listing fee");

    //tokenId에 해당하는 nft에 대한 소유권을 user -> marketplace contract로 이전
    IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);
    //list된 nft 수량 증가
    _nftCount.increment();

    //tokenId에 해당하는 nft의 seller를 msg.sender로, owner를 marketplace contract(소유권이 이전되었으므로)로 지정
    _idToNFT[_tokenId] = NFT(
      _nftContract,
      _tokenId, 
      payable(msg.sender),
      payable(address(this)),
      _price,
      true //리스트 여부
    );

    emit NFTListed(_nftContract, _tokenId, msg.sender, address(this), _price);
  }

  // Buy an NFT
  function buyNft(address _nftContract, uint256 _tokenId) public payable nonReentrant {
    //tokenId에 해당하는 nft정보를 받아와서 nft에 넣음 & 블록체인에 기록
    NFT storage nft = _idToNFT[_tokenId];
    require(msg.value >= nft.price, "Not enough ether to cover asking price");

    //msg.sender를 buyer로 지정
    address payable buyer = payable(msg.sender);
    //nft.seller에게 nft의 가격(msg.value)를 전송
    payable(nft.seller).transfer(msg.value);
    //tokenId에 해당하는 nft의 소유권을 marketplace contract -> buyer로 이전
    IERC721(_nftContract).transferFrom(address(this), buyer, nft.tokenId);
    //marketOwner에게 listing_fee 전송
    _marketOwner.transfer(LISTING_FEE);
    //buyer를 nft 구조체의 owner로 지정 (블록체인 기록)
    nft.owner = buyer;
    //nft의 list여부를 false로 바꿈 (블록체인 기록)
    nft.listed = false;

    //sold된 nft의 수량 1 증가
    _nftsSold.increment();
    emit NFTSold(_nftContract, nft.tokenId, nft.seller, buyer, msg.value);
  }

  // Resell an NFT purchased from the marketplace
  function resellNft(address _nftContract, uint256 _tokenId, uint256 _price) public payable nonReentrant {
    require(_price > 0, "Price must be at least 1 wei");
    require(msg.value == LISTING_FEE, "Not enough ether for listing fee");

    //tokenId에 해당하는 nft에 대한 소유권을 user -> marketplace contract로 이전
    IERC721(_nftContract).transferFrom(msg.sender, address(this), _tokenId);

    //tokenId에 해당하는 nft정보를 받아와서 nft에 넣음 & 블록체인에 기록
    NFT storage nft = _idToNFT[_tokenId];
    //msg.sender를 nft구조체의 seller로 지정 (블록체인 기록)
    nft.seller = payable(msg.sender); 
    //marketpalce contract를 nft 구조체의 owner로 지정 ; 소유권이 marketplace contract로 넘어가기 때문 (블록체인 기록)
    nft.owner = payable(address(this));
    //nft의 list여부를 true 바꿈 (블록체인 기록)
    nft.listed = true;
    //nft의 가격 설정 (블록체인 기록)
    nft.price = _price;

    //sold된 nft의 수량 1 감소
    _nftsSold.decrement();
    emit NFTListed(_nftContract, _tokenId, msg.sender, address(this), _price);
  }

  function getListingFee() public view returns (uint256) {
    return LISTING_FEE;
  }

  function getListedNfts() public view returns (NFT[] memory) {
    uint256 nftCount = _nftCount.current(); //현재 list된 nft 수량
    uint256 unsoldNftsCount = nftCount - _nftsSold.current(); // 현재 list된 nft 수량 -현재 팔린 nft 수량

    NFT[] memory nfts = new NFT[](unsoldNftsCount);
    uint nftsIndex = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].listed) { //해당 번호의 nft 구조체에서 listed가 true인 것을 nfts 배열에 담기
        nfts[nftsIndex] = _idToNFT[i + 1];
        nftsIndex++; // nftsIndex 증가
      }
    }
    return nfts;
  }

  function getMyNfts() public view returns (NFT[] memory) {
    uint nftCount = _nftCount.current(); //현재 list된 nft 수량
    uint myNftCount = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].owner == msg.sender) { //해당 번호의 nft 구조체에서 owner가 msg.sender일 경우 myNFTCount 증가
        myNftCount++;
      }
    }

    NFT[] memory nfts = new NFT[](myNftCount);
    uint nftsIndex = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].owner == msg.sender) { //해당 번호의 nft 구조체에서 owner가 msg.sender인 것을 nfts 배열에 담기
        nfts[nftsIndex] = _idToNFT[i + 1];
        nftsIndex++; // nftsIndex 증가
      }
    }
    return nfts;
  }

  function getMyListedNfts() public view returns (NFT[] memory) {
    uint nftCount = _nftCount.current();
    uint myListedNftCount = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].seller == msg.sender && _idToNFT[i + 1].listed) {
        myListedNftCount++;
      }
    }

    NFT[] memory nfts = new NFT[](myListedNftCount);
    uint nftsIndex = 0;
    for (uint i = 0; i < nftCount; i++) {
      if (_idToNFT[i + 1].seller == msg.sender && _idToNFT[i + 1].listed) {
        nfts[nftsIndex] = _idToNFT[i + 1];
        nftsIndex++;
      }
    }
    return nfts;
  }
}
