// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}

/// @notice Harbor Pass: an ERC-721 sold at a fixed price, at most two per wallet.
contract HarborPass {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    string public constant name = "Harbor Pass";
    string public constant symbol = "PASS";
    uint256 public constant PRICE = 0.05 ether;
    uint256 public constant MAX_PER_WALLET = 2;
    uint256 public constant MAX_SUPPLY = 500;

    address public immutable owner;
    uint256 public totalSupply;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;
    mapping(address => uint256) public mintedBy;

    constructor() {
        owner = msg.sender;
    }

    function mint(uint256 quantity) external payable {
        require(quantity > 0, "HarborPass: zero quantity");
        require(mintedBy[msg.sender] + quantity <= MAX_PER_WALLET, "HarborPass: wallet cap");
        require(totalSupply + quantity <= MAX_SUPPLY, "HarborPass: sold out");
        require(msg.value == PRICE * quantity, "HarborPass: wrong payment");
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, ++totalSupply);
        }
        mintedBy[msg.sender] += quantity;
    }

    function withdrawProceeds(address to) external {
        require(msg.sender == owner, "HarborPass: not owner");
        (bool ok,) = to.call{value: address(this).balance}("");
        require(ok, "HarborPass: transfer failed");
    }

    function approve(address spender, uint256 tokenId) external {
        address tokenOwner = ownerOf[tokenId];
        require(
            msg.sender == tokenOwner || isApprovedForAll[tokenOwner][msg.sender],
            "HarborPass: not authorized"
        );
        getApproved[tokenId] = spender;
        emit Approval(tokenOwner, spender, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(from == ownerOf[tokenId], "HarborPass: wrong from");
        require(to != address(0), "HarborPass: transfer to zero");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender]
                || msg.sender == getApproved[tokenId],
            "HarborPass: not authorized"
        );
        unchecked {
            balanceOf[from]--;
            balanceOf[to]++;
        }
        ownerOf[tokenId] = to;
        delete getApproved[tokenId];
        emit Transfer(from, to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal {
        require(to != address(0), "HarborPass: mint to zero");
        require(ownerOf[tokenId] == address(0), "HarborPass: already minted");
        balanceOf[to]++;
        ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
        if (to.code.length > 0) {
            require(
                IERC721Receiver(to).onERC721Received(msg.sender, address(0), tokenId, "")
                    == IERC721Receiver.onERC721Received.selector,
                "HarborPass: unsafe recipient"
            );
        }
    }
}
