#!/usr/bin/env ruby

# MLX Code - Xcode Project Generator
# Creates a complete macOS application project structure

require 'securerandom'
require 'fileutils'

# Generate UUIDs for Xcode project
def uuid
  SecureRandom.uuid.upcase.gsub('-', '')
end

# Project configuration
project_name = "MLX Code"
bundle_id = "com.local.mlxcode"
macos_target = "14.0"

# Generate all UUIDs upfront
uuids = {
  project: uuid,
  main_group: uuid,
  products_group: uuid,
  app_target: uuid,
  app_product_ref: uuid,
  sources_phase: uuid,
  frameworks_phase: uuid,
  resources_phase: uuid,
  copy_files_phase: uuid,

  # Frameworks
  framework_swiftui: uuid,
  framework_foundation: uuid,
  framework_appkit: uuid,
  framework_combine: uuid,
  framework_uniformtypeidentifiers: uuid,

  # Build configurations
  debug_project: uuid,
  release_project: uuid,
  config_list_project: uuid,
  debug_target: uuid,
  release_target: uuid,
  config_list_target: uuid,

  # Source files - App
  app_file: uuid,
  app_build: uuid,

  # Source files - Views
  content_view_file: uuid,
  content_view_build: uuid,
  chat_view_file: uuid,
  chat_view_build: uuid,
  message_row_file: uuid,
  message_row_build: uuid,
  settings_view_file: uuid,
  settings_view_build: uuid,
  model_selector_file: uuid,
  model_selector_build: uuid,

  # Source files - ViewModels
  chat_viewmodel_file: uuid,
  chat_viewmodel_build: uuid,

  # Source files - Models
  message_model_file: uuid,
  message_model_build: uuid,
  settings_model_file: uuid,
  settings_model_build: uuid,
  mlx_model_file: uuid,
  mlx_model_build: uuid,

  # Source files - Services
  mlx_service_file: uuid,
  mlx_service_build: uuid,
  xcode_service_file: uuid,
  xcode_service_build: uuid,
  file_service_file: uuid,
  file_service_build: uuid,
  python_service_file: uuid,
  python_service_build: uuid,

  # Source files - Utilities
  security_utils_file: uuid,
  security_utils_build: uuid,
  logger_file: uuid,
  logger_build: uuid,

  # Resources
  assets_file: uuid,
  assets_build: uuid,
  entitlements_file: uuid,

  # Groups
  views_group: uuid,
  viewmodels_group: uuid,
  models_group: uuid,
  services_group: uuid,
  utilities_group: uuid,
  resources_group: uuid,
}

# Create directory structure
dirs = [
  "MLX Code",
  "MLX Code/Views",
  "MLX Code/ViewModels",
  "MLX Code/Models",
  "MLX Code/Services",
  "MLX Code/Utilities",
  "MLX Code/Resources",
  "MLX Code Tests",
]

dirs.each { |dir| FileUtils.mkdir_p(dir) }

# Create project.pbxproj file
pbxproj_content = <<-PBXPROJ
// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
\t\t#{uuids[:app_build]} /* MLXCodeApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:app_file]} /* MLXCodeApp.swift */; };
\t\t#{uuids[:content_view_build]} /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:content_view_file]} /* ContentView.swift */; };
\t\t#{uuids[:chat_view_build]} /* ChatView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:chat_view_file]} /* ChatView.swift */; };
\t\t#{uuids[:message_row_build]} /* MessageRowView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:message_row_file]} /* MessageRowView.swift */; };
\t\t#{uuids[:settings_view_build]} /* SettingsView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:settings_view_file]} /* SettingsView.swift */; };
\t\t#{uuids[:model_selector_build]} /* ModelSelectorView.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:model_selector_file]} /* ModelSelectorView.swift */; };
\t\t#{uuids[:chat_viewmodel_build]} /* ChatViewModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:chat_viewmodel_file]} /* ChatViewModel.swift */; };
\t\t#{uuids[:message_model_build]} /* Message.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:message_model_file]} /* Message.swift */; };
\t\t#{uuids[:settings_model_build]} /* AppSettings.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:settings_model_file]} /* AppSettings.swift */; };
\t\t#{uuids[:mlx_model_build]} /* MLXModel.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:mlx_model_file]} /* MLXModel.swift */; };
\t\t#{uuids[:mlx_service_build]} /* MLXService.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:mlx_service_file]} /* MLXService.swift */; };
\t\t#{uuids[:xcode_service_build]} /* XcodeService.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:xcode_service_file]} /* XcodeService.swift */; };
\t\t#{uuids[:file_service_build]} /* FileService.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:file_service_file]} /* FileService.swift */; };
\t\t#{uuids[:python_service_build]} /* PythonService.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:python_service_file]} /* PythonService.swift */; };
\t\t#{uuids[:security_utils_build]} /* SecurityUtils.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:security_utils_file]} /* SecurityUtils.swift */; };
\t\t#{uuids[:logger_build]} /* SecureLogger.swift in Sources */ = {isa = PBXBuildFile; fileRef = #{uuids[:logger_file]} /* SecureLogger.swift */; };
\t\t#{uuids[:assets_build]} /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = #{uuids[:assets_file]} /* Assets.xcassets */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t#{uuids[:app_product_ref]} /* MLX Code.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "MLX Code.app"; sourceTree = BUILT_PRODUCTS_DIR; };
\t\t#{uuids[:app_file]} /* MLXCodeApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MLXCodeApp.swift; sourceTree = "<group>"; };
\t\t#{uuids[:content_view_file]} /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
\t\t#{uuids[:chat_view_file]} /* ChatView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ChatView.swift; sourceTree = "<group>"; };
\t\t#{uuids[:message_row_file]} /* MessageRowView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MessageRowView.swift; sourceTree = "<group>"; };
\t\t#{uuids[:settings_view_file]} /* SettingsView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SettingsView.swift; sourceTree = "<group>"; };
\t\t#{uuids[:model_selector_file]} /* ModelSelectorView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ModelSelectorView.swift; sourceTree = "<group>"; };
\t\t#{uuids[:chat_viewmodel_file]} /* ChatViewModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ChatViewModel.swift; sourceTree = "<group>"; };
\t\t#{uuids[:message_model_file]} /* Message.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Message.swift; sourceTree = "<group>"; };
\t\t#{uuids[:settings_model_file]} /* AppSettings.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AppSettings.swift; sourceTree = "<group>"; };
\t\t#{uuids[:mlx_model_file]} /* MLXModel.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MLXModel.swift; sourceTree = "<group>"; };
\t\t#{uuids[:mlx_service_file]} /* MLXService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MLXService.swift; sourceTree = "<group>"; };
\t\t#{uuids[:xcode_service_file]} /* XcodeService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = XcodeService.swift; sourceTree = "<group>"; };
\t\t#{uuids[:file_service_file]} /* FileService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FileService.swift; sourceTree = "<group>"; };
\t\t#{uuids[:python_service_file]} /* PythonService.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PythonService.swift; sourceTree = "<group>"; };
\t\t#{uuids[:security_utils_file]} /* SecurityUtils.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SecurityUtils.swift; sourceTree = "<group>"; };
\t\t#{uuids[:logger_file]} /* SecureLogger.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SecureLogger.swift; sourceTree = "<group>"; };
\t\t#{uuids[:assets_file]} /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
\t\t#{uuids[:entitlements_file]} /* MLX_Code.entitlements */ = {isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = MLX_Code.entitlements; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t#{uuids[:frameworks_phase]} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t#{uuids[:project]} = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:main_group]} /* MLX Code */,
\t\t\t\t#{uuids[:products_group]} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:main_group]} /* MLX Code */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:app_file]} /* MLXCodeApp.swift */,
\t\t\t\t#{uuids[:content_view_file]} /* ContentView.swift */,
\t\t\t\t#{uuids[:views_group]} /* Views */,
\t\t\t\t#{uuids[:viewmodels_group]} /* ViewModels */,
\t\t\t\t#{uuids[:models_group]} /* Models */,
\t\t\t\t#{uuids[:services_group]} /* Services */,
\t\t\t\t#{uuids[:utilities_group]} /* Utilities */,
\t\t\t\t#{uuids[:resources_group]} /* Resources */,
\t\t\t\t#{uuids[:entitlements_file]} /* MLX_Code.entitlements */,
\t\t\t);
\t\t\tpath = "MLX Code";
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:products_group]} /* Products */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:app_product_ref]} /* MLX Code.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:views_group]} /* Views */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:chat_view_file]} /* ChatView.swift */,
\t\t\t\t#{uuids[:message_row_file]} /* MessageRowView.swift */,
\t\t\t\t#{uuids[:settings_view_file]} /* SettingsView.swift */,
\t\t\t\t#{uuids[:model_selector_file]} /* ModelSelectorView.swift */,
\t\t\t);
\t\t\tpath = Views;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:viewmodels_group]} /* ViewModels */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:chat_viewmodel_file]} /* ChatViewModel.swift */,
\t\t\t);
\t\t\tpath = ViewModels;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:models_group]} /* Models */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:message_model_file]} /* Message.swift */,
\t\t\t\t#{uuids[:settings_model_file]} /* AppSettings.swift */,
\t\t\t\t#{uuids[:mlx_model_file]} /* MLXModel.swift */,
\t\t\t);
\t\t\tpath = Models;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:services_group]} /* Services */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:mlx_service_file]} /* MLXService.swift */,
\t\t\t\t#{uuids[:xcode_service_file]} /* XcodeService.swift */,
\t\t\t\t#{uuids[:file_service_file]} /* FileService.swift */,
\t\t\t\t#{uuids[:python_service_file]} /* PythonService.swift */,
\t\t\t);
\t\t\tpath = Services;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:utilities_group]} /* Utilities */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:security_utils_file]} /* SecurityUtils.swift */,
\t\t\t\t#{uuids[:logger_file]} /* SecureLogger.swift */,
\t\t\t);
\t\t\tpath = Utilities;
\t\t\tsourceTree = "<group>";
\t\t};
\t\t#{uuids[:resources_group]} /* Resources */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t#{uuids[:assets_file]} /* Assets.xcassets */,
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t#{uuids[:app_target]} /* MLX Code */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = #{uuids[:config_list_target]} /* Build configuration list for PBXNativeTarget "MLX Code" */;
\t\t\tbuildPhases = (
\t\t\t\t#{uuids[:sources_phase]} /* Sources */,
\t\t\t\t#{uuids[:frameworks_phase]} /* Frameworks */,
\t\t\t\t#{uuids[:resources_phase]} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = "MLX Code";
\t\t\tproductName = "MLX Code";
\t\t\tproductReference = #{uuids[:app_product_ref]} /* MLX Code.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t#{uuids[:project]} /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1600;
\t\t\t\tLastUpgradeCheck = 1600;
\t\t\t\tTargetAttributes = {
\t\t\t\t\t#{uuids[:app_target]} = {
\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t\tbuildConfigurationList = #{uuids[:config_list_project]} /* Build configuration list for PBXProject "MLX Code" */;
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = #{uuids[:project]};
\t\t\tproductRefGroup = #{uuids[:products_group]} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t#{uuids[:app_target]} /* MLX Code */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t#{uuids[:resources_phase]} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t#{uuids[:assets_build]} /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t#{uuids[:sources_phase]} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t#{uuids[:app_build]} /* MLXCodeApp.swift in Sources */,
\t\t\t\t#{uuids[:content_view_build]} /* ContentView.swift in Sources */,
\t\t\t\t#{uuids[:chat_view_build]} /* ChatView.swift in Sources */,
\t\t\t\t#{uuids[:message_row_build]} /* MessageRowView.swift in Sources */,
\t\t\t\t#{uuids[:settings_view_build]} /* SettingsView.swift in Sources */,
\t\t\t\t#{uuids[:model_selector_build]} /* ModelSelectorView.swift in Sources */,
\t\t\t\t#{uuids[:chat_viewmodel_build]} /* ChatViewModel.swift in Sources */,
\t\t\t\t#{uuids[:message_model_build]} /* Message.swift in Sources */,
\t\t\t\t#{uuids[:settings_model_build]} /* AppSettings.swift in Sources */,
\t\t\t\t#{uuids[:mlx_model_build]} /* MLXModel.swift in Sources */,
\t\t\t\t#{uuids[:mlx_service_build]} /* MLXService.swift in Sources */,
\t\t\t\t#{uuids[:xcode_service_build]} /* XcodeService.swift in Sources */,
\t\t\t\t#{uuids[:file_service_build]} /* FileService.swift in Sources */,
\t\t\t\t#{uuids[:python_service_build]} /* PythonService.swift in Sources */,
\t\t\t\t#{uuids[:security_utils_build]} /* SecurityUtils.swift in Sources */,
\t\t\t\t#{uuids[:logger_build]} /* SecureLogger.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t#{uuids[:debug_project]} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASUPP_CODE_SIGN_IDENTITY_AUTOMATIC = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = #{macos_target};
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t#{uuids[:release_project]} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASUPP_CODE_SIGN_IDENTITY_AUTOMATIC = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = #{macos_target};
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t#{uuids[:debug_target]} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASUPP_CODE_SIGN_STYLE = Automatic;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "MLX Code/MLX_Code.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "MLX Code";
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.developer-tools";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "#{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t#{uuids[:release_target]} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tASUPP_CODE_SIGN_STYLE = Automatic;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "MLX Code/MLX_Code.entitlements";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "MLX Code";
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.developer-tools";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "#{bundle_id}";
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t#{uuids[:config_list_project]} /* Build configuration list for PBXProject "MLX Code" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t#{uuids[:debug_project]} /* Debug */,
\t\t\t\t#{uuids[:release_project]} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t#{uuids[:config_list_target]} /* Build configuration list for PBXNativeTarget "MLX Code" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t#{uuids[:debug_target]} /* Debug */,
\t\t\t\t#{uuids[:release_target]} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */
\t};
\trootObject = #{uuids[:project]} /* Project object */;
}
PBXPROJ

# Write project file
FileUtils.mkdir_p("MLX Code.xcodeproj")
File.write("MLX Code.xcodeproj/project.pbxproj", pbxproj_content)

# Create xcschememanagement.plist
scheme_management = <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>SchemeUserState</key>
\t<dict>
\t\t<key>MLX Code.xcscheme_^#shared#^_</key>
\t\t<dict>
\t\t\t<key>orderHint</key>
\t\t\t<integer>0</integer>
\t\t</dict>
\t</dict>
</dict>
</plist>
PLIST

FileUtils.mkdir_p("MLX Code.xcodeproj/xcuserdata/#{ENV['USER']}.xcuserdatad/xcschemes")
File.write("MLX Code.xcodeproj/xcuserdata/#{ENV['USER']}.xcuserdatad/xcschemes/xcschememanagement.plist", scheme_management)

# Create shared scheme
shared_scheme = <<-SCHEME
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "#{uuids[:app_target]}"
               BuildableName = "MLX Code.app"
               BlueprintName = "MLX Code"
               ReferencedContainer = "container:MLX Code.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "#{uuids[:app_target]}"
            BuildableName = "MLX Code.app"
            BlueprintName = "MLX Code"
            ReferencedContainer = "container:MLX Code.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "#{uuids[:app_target]}"
            BuildableName = "MLX Code.app"
            BlueprintName = "MLX Code"
            ReferencedContainer = "container:MLX Code.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
SCHEME

FileUtils.mkdir_p("MLX Code.xcodeproj/xcshareddata/xcschemes")
File.write("MLX Code.xcodeproj/xcshareddata/xcschemes/MLX Code.xcscheme", shared_scheme)

puts "✅ Xcode project structure created successfully!"
puts "   Project: MLX Code.xcodeproj"
puts "   Bundle ID: #{bundle_id}"
puts "   Deployment Target: macOS #{macos_target}+"
PBXPROJ
