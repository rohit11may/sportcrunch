"""Method registration and discovery."""

from typing import Dict, Type

# Module-level registry stores method classes (not instances)
_METHOD_REGISTRY: Dict[str, Type["SegmentationMethod"]] = {}


def register_method(cls: Type["SegmentationMethod"]) -> Type["SegmentationMethod"]:
    """Decorator to register a segmentation method.

    Usage:
        @register_method
        class MyMethod(SegmentationMethod):
            ...

    Args:
        cls: Method class to register (must be a SegmentationMethod subclass)

    Returns:
        The class unchanged (decorator pattern)

    Raises:
        ValueError: If a method with the same name is already registered
    """
    # Instantiate to get name (requires no-arg constructor)
    instance = cls()
    name = instance.name

    if name in _METHOD_REGISTRY:
        raise ValueError(
            f"Method '{name}' already registered. "
            f"Each method must have a unique name."
        )

    # Store class (not instance) in registry
    _METHOD_REGISTRY[name] = cls
    return cls


def get_registered_methods() -> Dict[str, Type["SegmentationMethod"]]:
    """Return all registered method classes.

    Returns:
        Dictionary mapping method names to method classes
    """
    return dict(_METHOD_REGISTRY)


def get_method(name: str) -> Type["SegmentationMethod"]:
    """Get a specific method class by name.

    Args:
        name: Method name to retrieve

    Returns:
        Method class

    Raises:
        KeyError: If method is not registered
    """
    if name not in _METHOD_REGISTRY:
        available = list(_METHOD_REGISTRY.keys())
        raise KeyError(
            f"Unknown method: {name}. "
            f"Available methods: {available}"
        )
    return _METHOD_REGISTRY[name]
