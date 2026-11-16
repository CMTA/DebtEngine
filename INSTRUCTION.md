- Implement a flexible access control

```
abstract contract PauseModule is Pausable {
    // --- Modifiers ---
    modifier onlyPauseManager() {
        _authorizePause();
        _;
    }

    // --- External API ---
    function pause() public virtual onlyPauseManager {
        _pause();
    }

    // --- Authorization hook ---
    // Must revert if msg.sender is not allowed to pause
    function _authorizePause() internal virtual;
}

// Deployable contract – ownership-based policy
contract OwnablePauseAccess is PauseModule, Ownable {
    function _authorizePause() internal view override onlyOwner{}
}

```

- Once it is done, I want to DebtEngine version: one with the current AcessControl/RBAC, one with ownable from Openzeppelin