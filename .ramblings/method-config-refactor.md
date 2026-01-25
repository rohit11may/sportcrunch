Method configs should just be JSON and each method version, its implementation for a specific version should use whatever is in the JSON and these two things will be tightly coupled. To be able to pass it around to Swift, I understand you can't just be passing raw JSON everywhere. Visual validator and audio analyzer are Swift files related to the spectral flux method. They should probably be in the spectral flux family folder. In Core/Services, there shouldn't be method-specific services. VisualValidator and AudioAnalyzer should have prefixes 'SpectralFluxVisualValidator' and 'SpectralFluxAudioAnalyzer' and their MethodConfig should be SpectralFluxMethodConfig. Values for this method config shouldn't be hard coded anywhere in the swift. They should be read dynamically from the config file. The type just enforces a certain structure on the config file. 

When there is a new method family, you would need a new MethodConfig type for this Method. SegmentationMethod.swift should accept a generic/superset MethodConfig type.

---
In Sport.swift, sport and sport modes should map to 'Algorithm's. This is a new type made up of a SegmentationMethod and a method config. It's basically saying use this exact version of this method with these settings. 

---

There seems to be some code related to analysis preset in Sport.swift. And some deprecated stuff at the bottom of this file, investigate with a sub-agent and figure out whether it can be removed?