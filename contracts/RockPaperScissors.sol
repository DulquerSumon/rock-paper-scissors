// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

library Counters {
    struct Counter {
        uint256 _value;
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

contract RockPaperScissors {
    error LowStakeAmount();
    error PaymentError();
    error NotInCreatedState();
    error GameIsNotInJoinedState();
    error OnlyPlayersCanCall();
    error UnapprovedMove();
    error NotInComittedState();
    error MoveIdNotMatched();

    using Counters for Counters.Counter;
    enum State {
        CREATED,
        JOINED,
        COMMITED,
        REVEALED
    }
    struct Game {
        uint256 id;
        uint256 stakeAmount;
        address[2] players;
        State state;
    }
    struct Move {
        bytes32 hash;
        uint256 value;
    }
    mapping(uint256 => Game) private idToGame;
    Game[] private games;
    mapping(uint256 => mapping(address => Move)) private moves;
    mapping(uint256 => uint256) public winningMoves;
    Counters.Counter private gameId;
    IERC20 private tokenContract;

    constructor(address _tContract) {
        //rock
        //paper
        //scissors
        winningMoves[1] = 3;
        winningMoves[2] = 1;
        winningMoves[3] = 2;
        tokenContract = IERC20(_tContract);
    }

    function createGame(uint256 _sAmount) external payable {
        // require(msg.value > 0, "need to send some ether");
        if (_sAmount < 1 || _sAmount == 0) {
            revert LowStakeAmount();
        }
        address[2] memory players;
        players[0] = msg.sender;
        // players[1] = participant;
        gameId.increment();
        bool success = tokenContract.transferFrom(
            msg.sender,
            address(this),
            _sAmount
        );
        if (!success) {
            revert PaymentError();
        }
        Game memory game = Game(
            gameId.current(),
            _sAmount,
            players,
            State.CREATED
        );
        idToGame[gameId.current()] = game;
        games.push(game);
    }

    function joinGame(uint256 _gameId) external payable {
        Game storage game = idToGame[_gameId];
        // require(game.state == State.CREATED, "must be in created state");
        if (game.state != State.CREATED) {
            revert NotInCreatedState();
        }
        game.players[1] = msg.sender;
        bool success = tokenContract.transferFrom(
            msg.sender,
            address(this),
            game.stakeAmount
        );
        if (!success) {
            revert PaymentError();
        }
        game.state = State.JOINED;
    }

    function commitMove(
        uint256 _gameId,
        uint256 moveId,
        uint256 salt
    ) external {
        Game storage game = idToGame[_gameId];
        // require(game.state == State.JOINED, "game must be in joined state");
        if (game.state != State.JOINED) {
            revert GameIsNotInJoinedState();
        }
        // require(
        //     game.players[0] == msg.sender || game.players[1] == msg.sender,
        //     "can only be called by one of the players"
        // );
        if (game.players[0] != msg.sender || game.players[1] != msg.sender) {
            revert OnlyPlayersCanCall();
        }
        // require(
        //     moveId == 1 || moveId == 2 || moveId == 3,
        //     "move id must be either 1, 2, 3"
        // );
        if (moveId != 1 || moveId != 2 || moveId != 3) {
            revert UnapprovedMove();
        }
        moves[_gameId][msg.sender] = Move(
            keccak256(abi.encodePacked(moveId, salt)),
            0
        );
        if (
            moves[_gameId][game.players[0]].hash != 0 &&
            moves[_gameId][game.players[1]].hash != 0
        ) {
            game.state = State.COMMITED;
        }
    }

    function revealMove(
        uint256 _gameId,
        uint256 moveId,
        uint256 salt
    ) external {
        Game storage game = idToGame[_gameId];
        Move memory move1 = moves[_gameId][game.players[0]];
        Move memory move2 = moves[_gameId][game.players[1]];
        Move memory moveSender = moves[_gameId][msg.sender];
        // require(game.state == State.COMMITED, "game must be in commited state");
        if (game.state != State.COMMITED) {
            revert NotInComittedState();
        }
        // require(
        //     game.players[0] == msg.sender || game.players[1] == msg.sender,
        //     "can only be called by one of the players"
        // );
        if (game.players[0] != msg.sender || game.players[1] != msg.sender) {
            revert OnlyPlayersCanCall();
        }
        // require(
        //     moveSender.hash == keccak256(abi.encodePacked(moveId, salt)),
        //     "moveId does not match commitment"
        // );
        if (moveSender.hash != keccak256(abi.encodePacked(moveId, salt))) {
            revert MoveIdNotMatched();
        }
        moveSender.value = moveId;
        if (move1.value != 0 && move2.value != 0) {
            if (move1.value == move2.value) {
                // game.players[0].transfer(game.bet);
                tokenContract.transfer(game.players[0], game.stakeAmount);
                tokenContract.transfer(game.players[1], game.stakeAmount);
                // game.players[1].transfer(game.bet);
                game.state = State.REVEALED;
                return;
            }
            address winner;
            winner = winningMoves[move1.value] == move2.value
                ? game.players[0]
                : game.players[1];
            // winner.transfer(2 * game.bet);
            tokenContract.transfer(winner, game.stakeAmount);
            game.state = State.REVEALED;
        }
    }

    function getGameId() public view returns (uint256) {
        return gameId.current();
    }

    function getIdToGame(uint256 _id) public view returns (Game memory) {
        return idToGame[_id];
    }

    function getAvailableGame() public view returns (Game[] memory) {
        uint256 totalGame = gameId.current();
        uint256 availableGame;

        for (uint256 i = 0; i < totalGame; i++) {
            if (idToGame[i + 1].state == State.CREATED) {
                availableGame += 1;
            }
        }

        if (availableGame == 0) {
            return new Game[](0);
        }

        Game[] memory gameList = new Game[](availableGame);
        uint256 currentIndex;
        for (uint256 i = 0; i < totalGame; i++) {
            if (idToGame[i + 1].state == State.CREATED) {
                gameList[currentIndex] = idToGame[i + 1];
                currentIndex += 1;
            }
        }

        return gameList;
    }

    function getPlayersJoinedGamed() public view returns (Game[] memory) {
        uint256 totalGame = gameId.current();
        uint256 joinedGame;
        uint256 currentIndex;
        for (uint256 i = 0; i < totalGame; i++) {
            if (games[i + 1].state == State.JOINED) {
                if (
                    games[i + 1].players[0] == msg.sender ||
                    games[i + 1].players[1] == msg.sender
                ) {
                    joinedGame += 1;
                }
            }
        }
        Game[] memory gameList = new Game[](joinedGame);
        for (uint256 i = 0; i < totalGame; i++) {
            if (games[i + 1].state == State.JOINED) {
                if (
                    games[i + 1].players[0] == msg.sender ||
                    games[i + 1].players[1] == msg.sender
                ) {
                    gameList[currentIndex] = games[i + 1];
                    currentIndex += 1;
                }
            }
        }
        return gameList;
    }

    function getPlayersComitedGamed() public view returns (Game[] memory) {
        uint256 totalGame = gameId.current();
        uint256 commitedGame;
        uint256 currentIndex;
        for (uint256 i = 0; i < totalGame; i++) {
            if (games[i + 1].state == State.COMMITED) {
                if (
                    games[i + 1].players[0] == msg.sender ||
                    games[i + 1].players[1] == msg.sender
                ) {
                    commitedGame += 1;
                }
            }
        }
        Game[] memory gameList = new Game[](commitedGame);
        for (uint256 i = 0; i < totalGame; i++) {
            if (games[i + 1].state == State.COMMITED) {
                if (
                    games[i + 1].players[0] == msg.sender ||
                    games[i + 1].players[1] == msg.sender
                ) {
                    gameList[currentIndex] = games[i + 1];
                    currentIndex += 1;
                }
            }
        }
        return gameList;
    }

    function getRevealedGamed() public view returns (Game[] memory) {
        uint256 totalGame = gameId.current();
        uint256 revealedGame;
        uint256 currentIndex;
        for (uint256 i = 0; i < totalGame; i++) {
            if (games[i + 1].state == State.REVEALED) {
                revealedGame += 1;
            }
        }
        Game[] memory gameList = new Game[](revealedGame);
        for (uint256 i = 0; i < totalGame; i++) {
            if (games[i + 1].state == State.REVEALED) {
                gameList[currentIndex] = games[i + 1];
                currentIndex += 1;
            }
        }
        return gameList;
    }
}
