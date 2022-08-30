// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BoredPetsNFT is ERC721URIStorage {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  address marketplaceContract; //marketplace 컨트랙트의 주소 저장
  event NFTMinted(uint256); //NFT가 민팅될때마다 이벤트 발생. 이벤트가 발생할 때, 파라미터는 트랜잭션 로그에 저장

  constructor(address _marketplaceContract) ERC721("Bored Pets Yacht Club", "BPYC") {
    marketplaceContract = _marketplaceContract;
  }


  /**
   * parameter _tokenURI NFT의 메타데이터가 저장된 IPFS의 JSON 형식의 metadata가 있는 URI
   */
  function mint(string memory _tokenURI) public {
    _tokenIds.increment();
    uint256 newTokenId = _tokenIds.current();
    _safeMint(msg.sender, newTokenId); // _safeMint(address to, uint256 tokenId)  
    _setTokenURI(newTokenId, _tokenURI); //_setTokenURI(uint256 tokenId, string memory _tokenURI) 
    setApprovalForAll(marketplaceContract, true); // setApprovalForAll(address operator, bool approved)
  
  /**
   * marketplace 컨트랙트는 승인받은 사람이 NFT의 소유권 이전을 위해 여러 계정에 접근할 권한이 필요함
   */
    emit NFTMinted(newTokenId);
  }
}

/**
 * ERC721URIStorage를 상속하는 이유 ?
 * tokenURIs를 onChain의 storage에 저장하기 위해서
 * -> 이것은 메타데이터를 offChain의 IPFS에 올릴 수 있도록 함
 * 
 * 
 * Counters를 쓰는 이유?
 * 각각의 NFT에 고유한 token id를 할당하고, NFT의 수량을 트랙하기 위해서 
 * 
 *  */
