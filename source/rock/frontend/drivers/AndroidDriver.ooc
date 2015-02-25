
// sdk stuff
import io/[File, FileWriter]
import structs/[List, ArrayList, HashMap]

// our stuff
import Driver, Archive, SourceFolder, Flags, CCompiler

import rock/frontend/[BuildParams, Target]
import rock/middle/[Module, Use, UseDef]
import rock/backend/cnaughty/CGenerator

/**
 * Android NDK compilation driver - doesn't actually compile C files,
 * but prepares them in directories (one by SourceFolder) along with Android.mk
 * files for later compilation by ndk-build.
 *
 * In that case, ndk-build handles a lot of the work for us: dependencies,
 * partial recompilation, build flags - the Android.mk simili-Makefiles we
 * generate will be a lot shorter than the equivalent GNU Makefiles.
 */

AndroidDriver: class extends Driver {

	sourceFolders := HashMap<String, SourceFolder> new()

	init: func (.params) {
			super(params)
	}

	compile: func (module: Module) -> Int {
			"Android driver here, should compile module %s" printfln(module fullName)

			sourceFolders = collectDeps(module, HashMap<String, SourceFolder> new(), ArrayList<Module> new())

			// step 1: copy local headers
			params libcachePath = params outPath path
			copyLocals(module, params)

			// from then on, we handle the show - adjusting outPath as we go
			params libcache = false

			// step 2: generate C sources
			for (sourceFolder in sourceFolders) {
					generateSources(sourceFolder)
			}

			/* This is a hack by Emil to generate one single Android.mk file containing sources for every module */
			generateSingleMakefile(sourceFolders)
			return 0

			// step 3: generate Android.mk files
			for (sourceFolder in sourceFolders) {
					generateMakefile(sourceFolder)
			}

			0
	}

	/**
	 * Build a source folder into object files or a static library
	 */
	generateSources: func (sourceFolder: SourceFolder) {

			originalOutPath := params outPath
			params outPath = File new(originalOutPath, sourceFolder identifier)

			"Generating sources in %s" printfln(params outPath path)

			for(module in sourceFolder modules) {
					CGenerator new(params, module) write()
			}

			params outPath = originalOutPath

	}

	generateSingleMakefile: func (sourceFolders: HashMap<String, SourceFolder>) {
			dest := File new(File new(params outPath, "/"), "Android.mk")
			fw := FileWriter new(dest)
			fw write("LOCAL_PATH := $(call my-dir)\n")
			fw write("\n")

			localSharedLibraries := ArrayList<String> new()
			localStaticLibraries := ArrayList<String> new()
			for(sourceFolder in sourceFolders) {
				uses := collectUses(sourceFolder)
				for (useDef in uses) {
					for(lib in useDef androidLibs) {
						if(lib[0] == 'S') {
							if(!localStaticLibraries contains?(lib substring(1)))
								localStaticLibraries add(lib substring(1))
						}
						else {
							if(!localSharedLibraries contains?(lib))
								localSharedLibraries add(lib)
						}
					}
				}
			}

			if (!localSharedLibraries empty?()) {

					for (lib in localSharedLibraries) {
						//if(lib == "gc")
						//  continue
						fw write("include $(CLEAR_VARS)\n")
						fw write("LOCAL_MODULE := ")
						fw write(lib). write("\n")
						fw write("LOCAL_SRC_FILES := ")
						fw write(lib). write(".so\n")
						fw write("include $(PREBUILT_SHARED_LIBRARY)\n")
					}
					fw write("\n\n")
			}

			if (!localStaticLibraries empty?()) {

					for (lib in localStaticLibraries) {
						fw write("include $(CLEAR_VARS)\n")
						fw write("LOCAL_MODULE := ")
						fw write(lib). write("\n")
						fw write("LOCAL_SRC_FILES := ")
						fw write(lib). write(".a\n")
						fw write("include $(PREBUILT_STATIC_LIBRARY)\n")
					}
					fw write("\n\n")
			}

			fw write("include $(CLEAR_VARS)\n")
			fw write("\n")
			fw write("LOCAL_MODULE := "). write(params moduleName). write("\n")
			fw write("LOCAL_C_INCLUDES := ")
			for(sourceFolder in sourceFolders) {
				deps := collectSourceFolders(sourceFolder)
				for (dep in deps) {
				}
				fw write("$(LOCAL_PATH)/"). write(sourceFolder identifier). write(" ")
			}

			for(i in 0..this params defines size) {
				if(this params defines[i] != "__OOC_DEBUG__")
					fw write("\n"). write("LOCAL_CFLAGS += -D" + this params defines[i]). write("\n")
			}

			for(sourceFolder in sourceFolders) {
				uses := collectUses(sourceFolder)
				for (useDef in uses) {
						for (path in useDef androidIncludePaths) {
						}
				}
			}
			fw write("\n")
			fw write("\n")
			fw write("LOCAL_SRC_FILES := ")
			for(sourceFolder in sourceFolders) {
				for (module in sourceFolder modules) {
						path := module getPath(".c")
						fw write(sourceFolder identifier). write("/"). write(path). write(" ")
				}
			}
			for(sourceFolder in sourceFolders) {
				useDef := UseDef parse(sourceFolder identifier, params)
				if (useDef) {
						props := useDef getRelevantProperties(params)

						for (additional in props additionals) {
								cPath := File new(useDef identifier, additional relative path) path

								if (params verbose) {
										"cPath for additional: %s" printfln(cPath)
								}

								fw write(sourceFolder identifier). write("/"). write(cPath). write(" ")
						}
				}
			}
			fw write("\n")


			if (!localSharedLibraries empty?()) {
					fw write("LOCAL_SHARED_LIBRARIES := ")
					for (lib in localSharedLibraries) {
						fw write(lib). write(" ")
					}
					fw write("\n\n")
			}
			if (!localStaticLibraries empty?()) {
					fw write("LOCAL_STATIC_LIBRARIES := ")
					for (lib in localStaticLibraries) {
							fw write(lib). write(" ")
					}
					fw write("\n\n")
			}
			localLdLibs := ArrayList<String> new()
			for(sourceFolder in sourceFolders) {
				uses := collectUses(sourceFolder)
				for (useDef in uses) {
						props := useDef getRelevantProperties(params)
						for (lib in props libs) {
							if (!localLdLibs contains?(lib))
								localLdLibs add(lib)
						}
				}
			}
			fw write("\n")
			if (!localLdLibs empty?()) {
					fw write("LOCAL_LDLIBS := ")
					for (lib in localLdLibs) {
						fw write(lib). write(" ")
					}
					fw write("\n\n")
			}

			fw write("include $(BUILD_SHARED_LIBRARY)")

			fw close()
	}
	generateMakefile: func (sourceFolder: SourceFolder) {
			deps := collectSourceFolders(sourceFolder)
			uses := collectUses(sourceFolder)

			dest := File new(File new(params outPath, sourceFolder identifier), "Android.mk")
			fw := FileWriter new(dest)

			fw write("LOCAL_PATH := $(call my-dir)\n")
			fw write("\n")
			fw write("include $(CLEAR_VARS)\n")
			fw write("\n")
			fw write("LOCAL_MODULE := "). write(sourceFolder identifier). write("\n")
			fw write("LOCAL_C_INCLUDES := ")
			for (dep in deps) {
					fw write("$(LOCAL_PATH)/../"). write(dep identifier). write(" ")
			}
			fw write("$(LOCAL_PATH)/../"). write(sourceFolder identifier). write(" ")

			for (useDef in uses) {
					for (path in useDef androidIncludePaths) {
						if(path != "../gc/include")
							fw write("$(LOCAL_PATH)/"). write(path). write(" ")
					}
			}

			fw write("\n")
			fw write("\n")

			fw write("LOCAL_SRC_FILES := ")
			for (module in sourceFolder modules) {
					path := module getPath(".c")
					fw write(path). write(" ")
			}

			useDef := UseDef parse(sourceFolder identifier, params)
			if (useDef) {
					props := useDef getRelevantProperties(params)

					for (additional in props additionals) {
							cPath := File new(useDef identifier, additional relative path) path

							if (params verbose) {
									"cPath for additional: %s" printfln(cPath)
							}

							fw write(cPath). write(" ")
					}
			}
			fw write("\n")

			localSharedLibraries := ArrayList<String> new()
			for (useDef in uses) {
					localSharedLibraries addAll(useDef androidLibs)
			}

			for (dep in deps) {
					localSharedLibraries add(dep identifier)
			}

			if (!localSharedLibraries empty?()) {
					fw write("LOCAL_SHARED_LIBRARIES := ")
					for (lib in localSharedLibraries) {
						if(lib != "gc")
							fw write(lib). write(" ")
					}
					fw write("\n\n")
			}

			localLdLibs := ArrayList<String> new()
			for (useDef in uses) {
					props := useDef getRelevantProperties(params)
					localLdLibs addAll(props libs)
			}

			if (!localLdLibs empty?()) {
					fw write("LOCAL_LDLIBS := ")
					for (lib in localLdLibs) {
							fw write(lib). write(" ")
					}
					fw write("\n\n")
			}

			fw write("include $(BUILD_SHARED_LIBRARY)")

			fw close()
	}

	/** TODO: This is redundant with collectDeps, merge those */
	collectSourceFolders: func ~sourceFolders (sourceFolder: SourceFolder, \
					modulesDone := ArrayList<Module> new(), sourceFoldersDone := ArrayList<SourceFolder> new()) -> List<SourceFolder> {

			for (module in sourceFolder modules) {
					collectSourceFolders(module, modulesDone, sourceFoldersDone)
			}

			sourceFoldersDone filter(|sf| sf != sourceFolder)
	}

	collectSourceFolders: func ~modules (module: Module, \
					modulesDone := ArrayList<Module> new(), sourceFoldersDone := ArrayList<SourceFolder> new()) -> List<SourceFolder> {

			if (modulesDone contains?(module)) {
					return sourceFoldersDone
			}
			modulesDone add(module)

			for (uze in module getUses()) {
					useDef := uze useDef
					dep := sourceFolders get(useDef identifier)
					if (dep && !sourceFoldersDone contains?(dep)) {
							sourceFoldersDone add(dep)
					}
			}

			for (imp in module getAllImports()) {
					collectSourceFolders(imp getModule(), modulesDone, sourceFoldersDone)
			}

			sourceFoldersDone
	}

	doublePrefix: func -> Bool {
			true
	}

}
