"""JagX Passport — portable, verifiable identity for the JagX ecosystem.

A self-hostable engine for issuing, holding, presenting and verifying
W3C Verifiable Credentials 2.0, secured with the ``eddsa-jcs-2022``
Data Integrity cryptosuite and anchored to ``did:key`` / ``did:web``
decentralized identifiers.

By JagX and JRILICENSE.
"""

__version__ = "1.0.0"
__author__ = "JagX and JRILICENSE"
__license__ = "Apache-2.0"

BRAND = {
    "name": "JagX Passport",
    "vendor": "JagX and JRILICENSE",
    "tagline": "Prove it. Anywhere. Offline.",
    "theme": "#0a0a0a",
    "accent": "#f5c542",
}

__all__ = ["__version__", "__author__", "__license__", "BRAND"]
