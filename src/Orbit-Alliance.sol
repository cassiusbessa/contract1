// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function mint(address to, uint256 tokenId) external;
    function burn(address owner, uint256 tokenId) external;
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract GalactosSystem {
    address public staff;
    IERC721 public nft;

    mapping(address => int256) public balances;
    mapping(address => bool) public hasAuthorizedDeduction;
    
    struct Benefit {
        uint256 id;
        string name;
        string description;
        uint256 cost;
        bool requiresNFT;
        bool available;
        uint256[] requiredNFTs;
        uint256[] forbiddenNFTs;
    }
    
    struct NFTCategory {
        uint256 id;
        string name;
        string description;
        bool active;
        string artURI;  // Novo campo para armazenar a URI da arte
    }

    uint256 public benefitCount;
    mapping(uint256 => Benefit) public benefits;

    uint256 public categoryCount;
    mapping(uint256 => NFTCategory) public categories;
    mapping(address => uint256[]) public userNFTs;

    event TokensCredited(address indexed user, uint256 amount);
    event UserPenalized(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event BenefitCreated(uint256 benefitId, string name, uint256 cost);
    event BenefitUpdated(uint256 benefitId);
    event BenefitPurchased(address indexed user, uint256 benefitId);
    event NFTCategoryCreated(uint256 categoryId, string name, string artURI);  // Novo evento
    event NFTIssued(address indexed user, uint256 categoryId);
    event NFTBurned(address indexed user, uint256 categoryId);
    event AuthorizationGiven(address indexed user);
    event ArtUpdated(uint256 categoryId, string newArtURI);  // Evento para quando a arte for alterada

    modifier onlyStaff() {
        require(msg.sender == staff, "Apenas staff pode executar");
        _;
    }

    modifier notBlackholed() {
        require(!hasNFT(msg.sender, "Blackholed"), "Acesso bloqueado: Blackholed");
        _;
    }

    modifier notExpelled() {
        require(!hasNFT(msg.sender, "Expulso"), "Acesso bloqueado: Expulso");
        _;
    }

    constructor(address _staff, address _nft) {
        staff = _staff;
        nft = IERC721(_nft);
    }

    function airdrop(address user, uint256 amount) external onlyStaff {
        balances[user] += int256(amount);
        emit TokensCredited(user, amount);
    }

    function penalizeUser(address user, uint256 amount) external onlyStaff {
        balances[user] -= int256(amount);
        balances[staff] += int256(amount);
        emit UserPenalized(user, amount);
    }

    function transferTokens(address to, uint256 amount) external notBlackholed {
        require(balances[msg.sender] >= int256(amount), "Saldo insuficiente");
        balances[msg.sender] -= int256(amount);
        balances[to] += int256(amount);
        emit Transfer(msg.sender, to, amount);
    }

    function createBenefit(
        string calldata name,
        string calldata description,
        uint256 cost,
        bool requiresNFT,
        uint256[] calldata requiredNFTs,
        uint256[] calldata forbiddenNFTs
    ) external onlyStaff {
        benefitCount++;
        benefits[benefitCount] = Benefit(
            benefitCount, name, description, cost, requiresNFT, true, requiredNFTs, forbiddenNFTs
        );
        emit BenefitCreated(benefitCount, name, cost);
    }

    function updateBenefitNFTs(
        uint256 benefitId,
        string calldata name,
        string calldata description,
        uint256 cost,
        bool requiresNFT,
        uint256[] calldata requiredNFTs,
        uint256[] calldata forbiddenNFTs
    ) external onlyStaff {
        require(benefits[benefitId].available, "Beneficio nao existe");
        benefits[benefitId].name = name;
        benefits[benefitId].description = description;
        benefits[benefitId].cost = cost;
        benefits[benefitId].requiresNFT = requiresNFT;
        benefits[benefitId].requiredNFTs = requiredNFTs;
        benefits[benefitId].forbiddenNFTs = forbiddenNFTs;
        emit BenefitUpdated(benefitId);
    }

    // Função para alterar o URI da arte de um NFT
    function updateNFTArtURI(uint256 categoryId, string calldata newArtURI) external onlyStaff {
        require(categories[categoryId].active, "Categoria inativa");
        categories[categoryId].artURI = newArtURI;
        emit ArtUpdated(categoryId, newArtURI);
    }

    function purchaseBenefit(uint256 benefitId) public {
        Benefit memory benefit = benefits[benefitId];
        require(benefit.available, "Beneficio indisponivel");
        require(balances[msg.sender] >= int256(benefit.cost), "Saldo insuficiente");

        if (benefit.requiresNFT) {
            require(nft.balanceOf(msg.sender) > 0, "Beneficio exige NFT");
        }

        for (uint256 i = 0; i < benefit.requiredNFTs.length; i++) {
            require(hasNFT(msg.sender, categories[benefit.requiredNFTs[i]].name), string(abi.encodePacked("Falta NFT necessario: ", categories[benefit.requiredNFTs[i]].name)));
        }

        for (uint256 i = 0; i < benefit.forbiddenNFTs.length; i++) {
            require(!hasNFT(msg.sender, categories[benefit.forbiddenNFTs[i]].name), string(abi.encodePacked("Possui NFT proibido: ", categories[benefit.forbiddenNFTs[i]].name)));
        }

        balances[msg.sender] -= int256(benefit.cost);
        balances[staff] += int256(benefit.cost);
        emit BenefitPurchased(msg.sender, benefitId);
    }

    function getAllBenefits() external view returns (Benefit[] memory) {
        Benefit[] memory allBenefits = new Benefit[](benefitCount);
        for (uint256 i = 1; i <= benefitCount; i++) {
            allBenefits[i - 1] = benefits[i];
        }
        return allBenefits;
    }

    function createNFTCategory(string calldata name, string calldata description, string calldata artURI) external onlyStaff {
        categoryCount++;
        categories[categoryCount] = NFTCategory(categoryCount, name, description, true, artURI);
        emit NFTCategoryCreated(categoryCount, name, artURI);
    }


    function burnNFT(address student, uint256 categoryId) external onlyStaff {
        require(categories[categoryId].active, "Categoria inativa");
        nft.burn(student, categoryId);
        
        uint256[] storage nfts = userNFTs[student];
        for (uint256 i = 0; i < nfts.length; i++) {
            if (nfts[i] == categoryId) {
                nfts[i] = nfts[nfts.length - 1];
                nfts.pop();
                break;
            }
        }
        emit NFTBurned(student, categoryId);
    }

function hasNFT(address user, string memory categoryName) public view returns (bool) {
    for (uint256 i = 0; i < userNFTs[user].length; i++) {
        uint256 categoryId = userNFTs[user][i];
        if (keccak256(bytes(categories[categoryId].name)) == keccak256(bytes(categoryName))) {
            return true;
        }
    }
    return false;
}

    function getUserNFTs(address user) external view returns (uint256[] memory) {
        return userNFTs[user];
    }

function acceptCadetes(address[] calldata users) external onlyStaff {
    uint256 cadeteCategoryId = getCategoryIdByName("Cadete"); // Busca dinâmica do ID

    for (uint256 i = 0; i < users.length; i++) {
        hasAuthorizedDeduction[users[i]] = true;
        issueNFT(users[i], cadeteCategoryId);
        emit AuthorizationGiven(users[i]);
    }
}

    function issueNFT(address student, uint256 categoryId) public onlyStaff {
        require(categories[categoryId].active, "Categoria inativa");
        nft.mint(student, categoryId);
        userNFTs[student].push(categoryId);
        emit NFTIssued(student, categoryId);
    }

    function getCategoryIdByName(string memory categoryName) public view returns (uint256) {
    for (uint256 i = 1; i <= categoryCount; i++) {
        if (keccak256(bytes(categories[i].name)) == keccak256(bytes(categoryName))) {
            return categories[i].id;
        }
    }
    revert("Categoria nao encontrada");
}

// Retorna detalhes completos dos NFTs de um usuário
function getUserNFTDetails(address user) external view returns (NFTCategory[] memory) {
    uint256[] memory userNFTIds = userNFTs[user];
    NFTCategory[] memory nftDetails = new NFTCategory[](userNFTIds.length);

    for (uint256 i = 0; i < userNFTIds.length; i++) {
        nftDetails[i] = categories[userNFTIds[i]];
    }

    return nftDetails;
}

    
}
