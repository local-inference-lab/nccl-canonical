from __future__ import annotations

import os

from setuptools import Distribution, setup


class BinaryDistribution(Distribution):
    """Mark the data-only NCCL package as architecture-specific."""

    def has_ext_modules(self) -> bool:
        return True


setup(
    name="local-inference-nccl-cu133",
    version=os.environ["LOCAL_INFERENCE_NCCL_PACKAGE_VERSION"],
    description="Source-addressed NCCL runtime for LIL CUDA 13.3 SM120 serving",
    packages=["local_inference_nccl"],
    package_data={"local_inference_nccl": ["lib/*", "include/*", "include/**/*"]},
    include_package_data=True,
    python_requires=">=3.12,<3.13",
    distclass=BinaryDistribution,
    entry_points={
        "console_scripts": ["local-inference-nccl-path=local_inference_nccl:main"]
    },
)
