pragma solidity 0.5.16;

import "./ERC721.sol";
import "./ERC165.sol";
import "./SafeMath.sol";
import "./Address.sol";

contract DeedToken is ERC721, ERC165 {

    using SafeMath for uint256;
    using Address for address;

    address payable public owner;
    // ERC 165 를 구현하면서 selector true 저장값을 구현하기 위한 매핑
    mapping(bytes4 => bool) supportedInterfaces;

    // 토큰 아이디를 통해서 소유자 정보를 담는다.
    mapping(uint256 => address) tokenOwners;

    // 특정 어드레스가 가진 토큰의 수
    mapping(address => uint256) balances;
    // 어떤 토큰 아이디를 어떤 주소가 소유권을 가지고 있는가?
    mapping(uint256 => address) allowance;

    // 어떤 소유가 계정이 다수에게 자신이 가진 토큰을 관리할 수 있도록
    // true false 를 통해서 관리자 권한을 가지고 있는가
    // 앞에있는 address 는 소유자. 뒤의 address 는 중개인 계정
    mapping(address => mapping(address => bool)) operators;

    struct asset {
        uint8 x; // 얼굴
        uint8 y; // 눈
        uint8 z; // 입모양
    }

    //
    asset[] public allTokens;

    //for enumeration 유효한 토큰 아이디를 가지는 배열
    uint256[] public allValidTokenIds; //same as allTokens but does't have invalid tokens
    // 인덱싱을 매기기 위하여 토큰 아이디를 가지고 인덱스.
    // 앞 숫자는 토큰 아이디, 뒤의 숫자는 인덱스
    mapping(uint256 => uint256) private allValidTokenIndex;


    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    constructor() public {
        owner = msg.sender;
        supportedInterfaces[0x01ffc9a7] = true; //ERC165
        supportedInterfaces[0x80ac58cd] = true; //ERC721
    }

    function supportsInterface(bytes4 interfaceID) external view returns (bool){
        return supportedInterfaces[interfaceID];
    }

    // 이해함
    function balanceOf(address _owner) external view returns (uint256) {
        // address(0) =  NULL CHECK
        require(_owner != address(0));
        return balances[_owner];
    }
    // 이해함
    function ownerOf(uint256 _tokenId) public view returns (address) {

        address addr_owner = tokenOwners[_tokenId];
        require(
            addr_owner != address(0),
            "Token is invalid"
        );
        return addr_owner;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) public payable {

        // 토큰 아이디의 오너 주소를 가져옴
        address addr_owner = ownerOf(_tokenId);

        // 프롬과 오더 아이디가 같아야 한다
        require(
            addr_owner == _from,
            "_from is NOT the owner of the token"
        );

        // TO 에 대한 NULL 체크
        require(
            _to != address(0),
            "Transfer _to address 0x0"
        );

        address addr_allowed = allowance[_tokenId];
        bool isOp = operators[addr_owner][msg.sender];

        // 1. 요청자가 오너(tokenOwners)이거나,
        // 2. 요청자가 소유자(allowance) 이거나,
        // 3. 중개인이거나 operators[addr_owner][msg.sender]
        require(
            addr_owner == msg.sender || addr_allowed == msg.sender || isOp,
            "msg.sender does not have transferable token"
        );

        // 반영
        //transfer : change the owner of the token
        // 토큰 소유자 변경
        tokenOwners[_tokenId] = _to;
        balances[_from] = balances[_from].sub(1);
        balances[_to] = balances[_to].add(1);
        //reset approved address
        // 소유자 리셋
        if (allowance[_tokenId] != address(0)) {
            delete allowance[_tokenId];
        }

        // 트랜스퍼 되었다는 이벤트 발생
        emit Transfer(_from, _to, _tokenId);
    }

    // 기능상 transferFrom 과 동일함
    // to isContract() (address using for  에서 나옴) 를 사용하여 컨트랙트인 경우
    // 토큰을 이전받는 계정이 컨트랙트라면 ERC721TokenReceiver 를 구현하고 있어야함
    //
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory data) public payable {

        transferFrom(_from, _to, _tokenId);

        //check if _to is CA
        if (_to.isContract()) {
            bytes4 result = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, data);

            require(
                result == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")),
                "receipt of token is NOT completed"
            );
        }

    }

    // 파라미터가 하나 없는 safeTransferFrom 도 하는 일은 동일.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public payable {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    // approve 는 토큰 소유권 allowance 에다가 주소를 할당
    function approve(address _approved, uint256 _tokenId) external payable {

        address addr_owner = ownerOf(_tokenId);
        bool isOp = operators[addr_owner][msg.sender];

        require(
            addr_owner == msg.sender || isOp,
            "Not approved by owner"
        );

        allowance[_tokenId] = _approved;

        emit Approval(addr_owner, _approved, _tokenId);
    }

    // 강의봐도 잘 모르겠음. 업데이트 필요
    function setApprovalForAll(address _operator, bool _approved) external {
        operators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }


    function getApproved(uint256 _tokenId) external view returns (address) {
        return allowance[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return operators[_owner][_operator];
    }


    //non-ERC721 standard
    //
    //
    function () external payable {}

    // 토큰 생성
    function mint(uint8 _x, uint8 _y, uint8 _z) external payable {

        asset memory newAsset = asset(_x, _y, _z);
        // 푸시하고 나면 배열 길이가 나와서 거기서 -1 한 값을 tokenId 로 가진다.
        uint tokenId = allTokens.push(newAsset) - 1;
        //token id starts from 0, index of assets array
        tokenOwners[tokenId] = msg.sender;
        balances[msg.sender] = balances[msg.sender].add(1);

        //for enumeration
        allValidTokenIndex[tokenId] = allValidTokenIds.length;
        //index starts from 0
        allValidTokenIds.push(tokenId);

        emit Transfer(address(0), msg.sender, tokenId);
    }

    // 토큰을 삭제
    function burn(uint _tokenId) external {

        // 오너계정만이 토큰을 삭제할 수 있다.
        address addr_owner = ownerOf(_tokenId);

        require(
            addr_owner == msg.sender,
            "msg.sender is NOT the owner of the token"
        );

        // 존재하지 않을 토큰이기 때문에 allowance 에서 제거
        //reset approved address
        if (allowance[_tokenId] != address(0)) {
            delete allowance[_tokenId];
            // tokenId => 0
        }

        //transfer : change the owner of the token, but address(0)
        tokenOwners[_tokenId] = address(0);
        balances[msg.sender] = balances[msg.sender].sub(1);

        //for enumeration
        removeInvalidToken(_tokenId);

        emit Transfer(addr_owner, address(0), _tokenId);
    }

    function removeInvalidToken(uint256 tokenIdToRemove) private {

        // 마지막 인덱스와 폐기되는 인덱스를 구한다
        uint256 lastIndex = allValidTokenIds.length.sub(1);
        uint256 removeIndex = allValidTokenIndex[tokenIdToRemove];

        uint256 lastTokenId = allValidTokenIds[lastIndex];

        //swap
        allValidTokenIds[removeIndex] = lastTokenId;
        allValidTokenIndex[lastTokenId] = removeIndex;

        //delete
        //Arrays have a length member to hold their number of elements.
        //Dynamic arrays can be resized in storage (not in memory) by changing the .length member.
        allValidTokenIds.length = allValidTokenIds.length.sub(1);
        //allValidTokenIndex is private so can't access invalid token by index programmatically
        allValidTokenIndex[tokenIdToRemove] = 0;
    }

    //ERC721Enumerable
    // 유효한 토큰의 전체 갯수
    function totalSupply() public view returns (uint) {
        return allValidTokenIds.length;
    }

    //ERC721Enumerable
    // 인덱스로 토큰 아이디를 가져오는 것
    function tokenByIndex(uint256 index) public view returns (uint256) {
        require(index < totalSupply());
        return allValidTokenIds[index];
    }

    //ERC721Metadata
    function name() external pure returns (string memory) {
        return "EMOJI TOKEN";
    }

    //ERC721Metadata
    function symbol() external pure returns (string memory) {
        return "EMJ";
    }

    function kill() external onlyOwner {
        selfdestruct(owner);
    }


}

contract ERC721TokenReceiver {

    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data) public returns (bytes4);
}
