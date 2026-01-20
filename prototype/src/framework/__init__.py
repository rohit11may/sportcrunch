"""
Framework for multi-method video segmentation comparison.

Usage:
    from src.framework import SegmentationMethod, MethodResult, register_method
    from src import methods  # Import to trigger registration
    from src.framework import get_registered_methods

    methods = get_registered_methods()
    for name, cls in methods.items():
        method = cls()
        result = method.analyze("video.mp4")
"""

from .method_base import SegmentationMethod
from .result import MethodResult, ConfigSpec, ParamDef, ParamType, BaseState
from .registry import register_method, get_registered_methods, get_method

__all__ = [
    "SegmentationMethod",
    "MethodResult",
    "ConfigSpec",
    "ParamDef",
    "ParamType",
    "BaseState",
    "register_method",
    "get_registered_methods",
    "get_method",
]
