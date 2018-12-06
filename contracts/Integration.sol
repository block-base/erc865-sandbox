pragma solidity ^0.4.23;

import "./openzeppelin-solidity/contracts/token/ERC721/ERC721Full.sol";

contract Integration is ERC721Full{

    struct Token {
        string content;
        address publisher;
    }

    struct Market {
        address seller;
        uint    price;
        bool    exist;
    }    

    mapping (string => uint) contentToTokenId;
    mapping(uint => Market) public markets;

    Token[] public tokens;

    string public tokenURIPrefix = "https://erc865.glitch.me/token?id=";

    event Sell(uint _tokenId, uint _price);
    event CancelMarket(uint _tokenId);
    event Purchase(uint _tokenId);
    event Request(uint _fromId, uint _toId);
    event CancelExchange(uint _tokenId);
    event Confirm(uint _tokenId);

    constructor (

    ) ERC721Full(
        "SmartContents",
        "SC"
    ) public {

    }    

    function getContentToTokenId(string _content) public view returns (uint256){
        return contentToTokenId[_content];
    }

    function mint(string _content, uint128 _price, bytes _sig) public payable {
        require(contentToTokenId[_content] == 0);

        bytes32 _dataHash = keccak256(_content);
        bytes32 _prefixedHash = keccak256("\x19Ethereum Signed Message:\n32", _dataHash);

        address _recovered = getRecoveredAddress(_sig, _prefixedHash);
        require(_recovered != address(0));

        Token memory _token = Token({content: _content, publisher: _recovered});

        uint _tokenId = tokens.push(_token) - 1;
        contentToTokenId[_content] = _tokenId;
        
        _mint(address(this), _tokenId);
        Market memory _market = Market(_recovered, _price, true);
        markets[_tokenId] = _market;
        emit Sell(_tokenId, _price);
    }    


    function sell(uint _tokenId, uint128 _price) public {
        require(!markets[_tokenId].exist);

        Market memory _market = Market(msg.sender, _price, true);
        markets[_tokenId] = _market;
        transferFrom(msg.sender, address(this), _tokenId);
        emit Sell(_tokenId, _price);

    }

    function cancelMarket(uint _tokenId) public {
        require(markets[_tokenId].exist);
        require(markets[_tokenId].seller == msg.sender);

        this.transferFrom(address(this), msg.sender, _tokenId);
        delete markets[_tokenId];
        emit CancelMarket(_tokenId);
    }

    function purchase(uint _tokenId) public payable {
        require(markets[_tokenId].exist);
        require(markets[_tokenId].seller != msg.sender);
        require(markets[_tokenId].price == msg.value);
      
        Market memory _market = markets[_tokenId];
        delete markets[_tokenId];
        this.transferFrom(address(this), msg.sender, _tokenId);      

        if (_market.price > 0) {
            _market.seller.transfer(msg.value); 
        }
        emit Purchase(_tokenId);

    }

    function ownedTokens(address _address) public returns (uint[]) {
        return _ownedTokens[_address];
    }

    function tokenURI(uint _tokenId) external view returns (string) {
        bytes32 tokenIdBytes;
        if (_tokenId == 0) {
            tokenIdBytes = "0";
        } else {
            uint value = _tokenId;
            while (value > 0) {
                tokenIdBytes = bytes32(uint256(tokenIdBytes) / (2 ** 8));
                tokenIdBytes |= bytes32(((value % 10) + 48) * 2 ** (8 * 31));
                value /= 10;
            }
        }

        bytes memory prefixBytes = bytes(tokenURIPrefix);
        bytes memory tokenURIBytes = new bytes(prefixBytes.length + tokenIdBytes.length);

        uint i;
        uint index = 0;
        
        for (i = 0; i < prefixBytes.length; i++) {
            tokenURIBytes[index] = prefixBytes[i];
            index++;
        }
        
        for (i = 0; i < tokenIdBytes.length; i++) {
            tokenURIBytes[index] = tokenIdBytes[i];
            index++;
        }
        
        return string(tokenURIBytes);
    }

    function getRecoveredAddress(bytes sig, bytes32 dataHash)
        public
        view
        returns (address addr)
    {
        bytes32 ra;
        bytes32 sa;
        uint8 va;

        // Check the signature length
        if (sig.length != 65) {
            return (0);
        }

        // Divide the signature in r, s and v variables
        assembly {
            ra := mload(add(sig, 32))
            sa := mload(add(sig, 64))
            va := byte(0, mload(add(sig, 96)))
        }

        if (va < 27) {
            va += 27;
        }

        address recoveredAddress = ecrecover(dataHash, va, ra, sa);

        return (recoveredAddress);
    }

}