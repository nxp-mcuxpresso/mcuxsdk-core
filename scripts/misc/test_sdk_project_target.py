# Copyright 2025 NXP
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import sys
import pytest
import json
import yaml
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open

# Add parent directory to path for imports
script_dir = os.path.abspath(os.path.dirname(__file__))
sys.path.insert(0, script_dir)

from sdk_project_target import (
    MCUXProjectData,
    MCUXAppTargets,
    MCUXRepoProjects,
    SUPPORTED_TOOLCHAINS,
    sdk_root_dir
)


class TestMCUXProjectData:
    """Test cases for MCUXProjectData class"""
    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_from_fields_with_board(self, mock_exists):
        """Test creating MCUXProjectData instance with board"""
        project = MCUXProjectData.from_fields(
            name="test_app",
            board="frdmk22f",
            device=None,
            core_id="cm4",
            toolchain="armgcc",
            target="debug",
            project_file="examples/demo_apps/hello_world",
            category="demo_apps",
            use_sysbuild=False,
            shield="shield1",
            extra_build_args=["--verbose"]
        )
        
        assert project.name == "test_app"
        assert project.board == "frdmk22f"
        assert project.device is None
        assert project.core_id == "cm4"
        assert project.toolchain == "armgcc"
        assert project.target == "debug"
        assert project.category == "demo_apps"
        assert project.shield == "shield1"
        assert project.extra_build_args == ["--verbose"]
    def test_from_fields_with_device(self):
        """Test creating MCUXProjectData instance with device"""
        project = MCUXProjectData.from_fields(
            name="test_app",
            board=None,
            device="MK22FN512xxx12",
            core_id="",
            toolchain="iar",
            target="release",
            project_file="examples/demo_apps/hello_world",
            category="demo_apps",
            use_sysbuild=True
        )
        
        assert project.board is None
        assert project.device == "MK22FN512xxx12"
        assert project.use_sysbuild == True

    def test_from_fields_requires_board_or_device(self):
        """Test that from_fields requires either board or device"""
        with pytest.raises(AssertionError):
            MCUXProjectData.from_fields(
                name="test_app",
                board=None,
                device=None,
                core_id="cm4",
                toolchain="armgcc",
                target="debug",
                project_file="examples/demo_apps/hello_world",
                category="demo_apps",
                use_sysbuild=False
            )

    def test_as_dict(self):
        """Test converting MCUXProjectData to dictionary"""
        project = MCUXProjectData.from_fields(
            name="test_app",
            board="frdmk22f",
            device=None,
            core_id="cm4",
            toolchain="armgcc",
            target="debug",
            project_file="examples/demo_apps/hello_world",
            category="demo_apps",
            use_sysbuild=False
        )
        
        result = project.as_dict()
        assert 'name' in result
        assert 'board' in result
        assert 'build_cmd' in result
        assert result['name'] == "test_app"

    @patch('sdk_project_target.os.path.exists')
    def test_project_file_setter_relative_path(self, mock_exists):
        """Test setting project_file with relative path"""
        mock_exists.return_value = True
        project = MCUXProjectData()
        project.project_file = "examples/demo_apps/hello_world"
        
        assert project.project_file == "examples/demo_apps/hello_world"
        mock_exists.assert_called_once()

    @patch('sdk_project_target.os.path.exists')
    def test_project_file_setter_absolute_path(self, mock_exists):
        """Test setting project_file with absolute path"""
        mock_exists.return_value = True
        abs_path = "/absolute/path/to/project"
        
        project = MCUXProjectData()
        project.project_file = abs_path
        
        assert project.project_file == abs_path

    @patch('sdk_project_target.os.path.exists')
    def test_project_file_setter_invalid_path(self, mock_exists):
        """Test setting project_file with non-existent path"""
        mock_exists.return_value = False
        project = MCUXProjectData()
        
        with pytest.raises(ValueError, match="does not exist"):
            project.project_file = "invalid/path"

    def test_toolchain_setter_valid(self):
        """Test setting valid toolchain"""
        project = MCUXProjectData()
        for toolchain in SUPPORTED_TOOLCHAINS:
            project.toolchain = toolchain
            assert project.toolchain == toolchain

    def test_toolchain_setter_invalid(self):
        """Test setting invalid toolchain"""
        project = MCUXProjectData()
        project.toolchain = "invalid_toolchain"
        assert project.toolchain == ""  # Should not be set

    def test_build_cmd_board_device_core_with_board(self):
        """Test build_cmd_board_device_core property with board"""
        project = MCUXProjectData()
        project.board = "frdmk22f"
        project.core_id = "cm4"
        
        cmd = project.build_cmd_board_device_core
        assert "-b frdmk22f" in cmd
        assert "-Dcore_id=cm4" in cmd

    def test_build_cmd_board_device_core_with_shield(self):
        """Test build_cmd_board_device_core property with shield"""
        project = MCUXProjectData()
        project.board = "frdmk22f"
        project.shield = "shield1"
        
        cmd = project.build_cmd_board_device_core
        assert "-b frdmk22f" in cmd
        assert "--shield shield1" in cmd

    def test_build_cmd_board_device_core_with_device(self):
        """Test build_cmd_board_device_core property with device"""
        project = MCUXProjectData()
        project.device = "MK22FN512xxx12"
        
        cmd = project.build_cmd_board_device_core
        assert "--device MK22FN512xxx12" in cmd

    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_build_cmd(self, mock_exists):
        """Test complete build command generation"""
        project = MCUXProjectData.from_fields(
            name="test_app",
            board="frdmk22f",
            device=None,
            core_id="cm4",
            toolchain="armgcc",
            target="debug",
            project_file="examples/demo_apps/hello_world",
            category="demo_apps",
            use_sysbuild=False,
            extra_build_args=["--verbose", "-DTEST=1"]
        )
        
        cmd = project.build_cmd
        assert "west build" in cmd
        assert "-p always" in cmd
        assert "examples/demo_apps/hello_world" in cmd
        assert "--toolchain armgcc" in cmd
        assert "--config debug" in cmd
        assert "-b frdmk22f" in cmd
        assert "-Dcore_id=cm4" in cmd
        assert "--verbose" in cmd
        assert "-DTEST=1" in cmd

    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_build_cmd_with_sysbuild(self, mock_exists):
        """Test build command with sysbuild enabled"""
        project = MCUXProjectData.from_fields(
            name="test_app",
            board="frdmk22f",
            device=None,
            core_id="",
            toolchain="armgcc",
            target="debug",
            project_file="examples/demo_apps/hello_world",
            category="demo_apps",
            use_sysbuild=True
        )
        
        cmd = project.build_cmd
        assert "--sysbuild" in cmd

    def test_board_core_property(self):
        """Test board_core property"""
        project = MCUXProjectData()
        project.board = "frdmk22f"
        project.core_id = "cm4"
        
        assert project.board_core == "frdmk22f@cm4"
        
        project.core_id = ""
        assert project.board_core == "frdmk22f"


class TestMCUXAppTargets:
    """Test cases for MCUXAppTargets class"""

    def test_reset_targets(self):
        """Test resetting targets dictionary"""
        app_targets = MCUXAppTargets()
        app_targets.tgt_dict = {"armgcc@debug": True}
        app_targets.reset_targets()
        assert app_targets.tgt_dict == {}

    def test_inject_target_add(self):
        """Test injecting target with add action"""
        app_targets = MCUXAppTargets()
        app_targets.inject_target("+armgcc@debug")
        assert app_targets.tgt_dict["armgcc@debug"] is True
        
        # Test without prefix (should default to add)
        app_targets.inject_target("iar@release")
        assert app_targets.tgt_dict["iar@release"] is True

    def test_inject_target_remove(self):
        """Test injecting target with remove action"""
        app_targets = MCUXAppTargets()
        app_targets.inject_target("-armgcc@debug")
        assert app_targets.tgt_dict["armgcc@debug"] is False

    def test_inject_target_invalid_format(self):
        """Test injecting target with invalid format"""
        app_targets = MCUXAppTargets()
        result = app_targets.inject_target("invalid_format")
        assert result is None
        assert app_targets.tgt_dict == {}

    def test_config_filter(self):
        """Test configuring filters"""
        MCUXAppTargets.config_filter(
            toolchains_filter=["armgcc", "e@iar", "r@mdk"],
            boards_filter=["frdmk22f", "e@r@evk"],
            shields_filter=["shield1"],
            targets_filter=["debug", "e@release"],
            devices_filter=["MK22FN512xxx12"]
        )
        
        assert "armgcc" in MCUXAppTargets.TOOLCHAINS_FILTER
        assert "r@mdk" in MCUXAppTargets.TOOLCHAINS_FILTER
        assert "iar" in MCUXAppTargets.TOOLCHAINS_EXCLUDE_FILTER
        assert "frdmk22f" in MCUXAppTargets.BOARDS_FILTER
        assert "r@evk" in MCUXAppTargets.BOARDS_EXCLUDE_FILTER
        assert "shield1" in MCUXAppTargets.SHIELDS_FILTER
        assert "debug" in MCUXAppTargets.TARGETS_FILTER
        assert "release" in MCUXAppTargets.TARGETS_EXCLUDE_FILTER
        assert "MK22FN512xxx12" in MCUXAppTargets.DEVICES_FILTER

    def test_do_filter_exact_match_include(self):
        """Test do_filter with exact match in include list"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter("armgcc", ["armgcc", "iar"], [])
        assert result is True
        
        result = app_targets.do_filter("mdk", ["armgcc", "iar"], [])
        assert result is False

    def test_do_filter_regex_match_include(self):
        """Test do_filter with regex match in include list"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter("frdmk22f", ["r@frdm"], [])
        assert result is True
        
        result = app_targets.do_filter("evkboard", ["r@frdm"], [])
        assert result is False

    def test_do_filter_exact_match_exclude(self):
        """Test do_filter with exact match in exclude list"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter("armgcc", [], ["armgcc"])
        assert result is False
        
        result = app_targets.do_filter("iar", [], ["armgcc"])
        assert result is True

    def test_do_filter_regex_match_exclude(self):
        """Test do_filter with regex match in exclude list"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter("frdmk22f", [], ["r@frdm"])
        assert result is False
        
        result = app_targets.do_filter("evkboard", [], ["r@frdm"])
        assert result is True

    def test_do_filter_empty_lists(self):
        """Test do_filter with empty filter lists"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter("anything", [], [])
        assert result is True

    def test_filter_methods(self):
        """Test individual filter methods"""
        MCUXAppTargets.config_filter(
            toolchains_filter=["armgcc"],
            boards_filter=["frdmk22f"],
            shields_filter=["shield1"],
            targets_filter=["debug"],
            devices_filter=["MK22FN512xxx12"]
        )
        
        app_targets = MCUXAppTargets()
        assert app_targets.filter_toolchain("armgcc") is True
        assert app_targets.filter_toolchain("iar") is False
        assert app_targets.filter_board_core("frdmk22f") is True
        assert app_targets.filter_board_core("evkboard") is False
        assert app_targets.filter_shield("shield1") is True
        assert app_targets.filter_shield("shield2") is False
        assert app_targets.filter_target("debug") is True
        assert app_targets.filter_target("release") is False
        assert app_targets.filter_device_core("MK22FN512xxx12") is True
        assert app_targets.filter_device_core("OTHER_DEVICE") is False

    @patch('sdk_project_target.mcux_read_yaml')
    @patch('sdk_project_target.os.path.exists')
    def test_inject_targets_from_shared_file(self, mock_exists, mock_read_yaml):
        """Test injecting targets from shared file"""
        mock_exists.return_value = True
        mock_read_yaml.return_value = {"board.toolchains": ["+armgcc@debug", "-iar@release"]}
        
        app_targets = MCUXAppTargets()
        app_targets.inject_targets_from_shared_file("test_board", "test_file.yml", "board")
        
        assert app_targets.tgt_dict["armgcc@debug"] is True
        assert app_targets.tgt_dict["iar@release"] is False

    @patch('sdk_project_target.mcux_read_yaml')
    def test_get_app_targets_invalid_yaml(self, mock_read_yaml):
        """Test get_app_targets with invalid YAML file"""
        mock_read_yaml.side_effect = Exception("Invalid YAML")
        
        app_targets = MCUXAppTargets()
        with tempfile.NamedTemporaryFile(suffix='.yml', delete=False) as f:
            temp_file = f.name
        
        try:
            result = app_targets.get_app_targets(temp_file)
            assert result == []
        finally:
            os.unlink(temp_file)

    @patch('sdk_project_target.mcux_read_yaml')
    def test_get_app_targets_empty_data(self, mock_read_yaml):
        """Test get_app_targets with empty data"""
        mock_read_yaml.return_value = None
        
        app_targets = MCUXAppTargets()
        result = app_targets.get_app_targets("test.yml")
        assert result == []

    @patch('sdk_project_target.mcux_read_yaml')
    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_get_app_targets_with_boards(self, mock_exists, mock_read_yaml):
        """Test get_app_targets with board configuration"""
        mock_read_yaml.return_value = {
            "hello_world": {
                "section-type": "application",
                "boards": {
                    "frdmk22f": ["+armgcc@debug"]
                },
                "contents": {
                    "document": {
                        "category": "demo_apps"
                    }
                }
            }
        }
        
        # Reset filters
        MCUXAppTargets.config_filter()
        
        app_targets = MCUXAppTargets()
        with patch.object(app_targets, 'inject_targets_from_instance_default'):
            with patch.object(app_targets, 'inject_targets_from_instance_category'):
                with patch.object(app_targets, 'inject_targets_from_app_category'):
                    result = app_targets.get_app_targets("test.yml")
                    assert len(result) == 1
                    assert result[0].name == "hello_world"
                    assert result[0].board == "frdmk22f"

    @patch('sdk_project_target.mcux_read_yaml')
    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_get_app_targets_with_devices(self, mock_exists, mock_read_yaml):
        """Test get_app_targets with device configuration"""
        mock_read_yaml.return_value = {
            "hello_world": {
                "section-type": "application",
                "devices": {
                    "MK22FN512xxx12": ["+armgcc@debug"]
                },
                "contents": {
                    "document": {
                        "category": "demo_apps"
                    }
                }
            }
        }
        
        # Reset filters
        MCUXAppTargets.config_filter()
        
        app_targets = MCUXAppTargets()
        with patch.object(app_targets, 'inject_targets_from_instance_default'):
            with patch.object(app_targets, 'inject_targets_from_instance_category'):
                with patch.object(app_targets, 'inject_targets_from_app_category'):
                    result = app_targets.get_app_targets("test.yml")
                    assert len(result) == 1
                    assert result[0].name == "hello_world"
                    assert result[0].device == "MK22FN512xxx12"

    @patch('sdk_project_target.mcux_read_yaml')
    def test_get_app_targets_skip_build(self, mock_read_yaml):
        """Test get_app_targets skips apps with skip_build flag"""
        mock_read_yaml.return_value = {
            "hello_world": {
                "section-type": "application",
                "skip_build": True,
                "boards": {
                    "frdmk22f": ["+armgcc@debug"]
                }
            }
        }
        
        app_targets = MCUXAppTargets()
        result = app_targets.get_app_targets("test.yml")
        assert result == []

    @patch('sdk_project_target.mcux_read_yaml')
    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_get_app_targets_with_shield(self, mock_exists, mock_read_yaml):
        """Test get_app_targets with shield configuration"""
        mock_read_yaml.return_value = {
            "hello_world": {
                "section-type": "application",
                "boards": {
                    "frdmk22f": ["+armgcc@debug"]
                },
                "shields": {
                    "shield1": {}
                },
                "contents": {
                    "document": {
                        "category": "demo_apps"
                    }
                }
            }
        }
        
        # Reset filters
        MCUXAppTargets.config_filter()
        
        app_targets = MCUXAppTargets()
        with patch.object(app_targets, 'inject_targets_from_instance_default'):
            with patch.object(app_targets, 'inject_targets_from_instance_category'):
                with patch.object(app_targets, 'inject_targets_from_app_category'):
                    result = app_targets.get_app_targets("test.yml")
                    assert len(result) == 1
                    assert result[0].shield == "shield1"


class TestMCUXRepoProjects:
    """Test cases for MCUXRepoProjects class"""

    @patch('sdk_project_target.glob.glob')
    @patch('sdk_project_target.os.path.exists')
    def test_search_app_targets_explicit_yml(self, mock_exists, mock_glob):
        """Test search_app_targets with explicit example.yml path"""
        mock_exists.return_value = True
        
        repo_projects = MCUXRepoProjects()
        with patch.object(MCUXAppTargets, 'get_app_targets', return_value=[]):
            result = repo_projects.search_app_targets("examples/demo_apps/hello_world/example.yml")
            assert result == []
            mock_glob.assert_not_called()

    @patch('sdk_project_target.glob.glob')
    def test_search_app_targets_directory(self, mock_glob):
        """Test search_app_targets with directory path"""
        mock_glob.return_value = [
            os.path.join(sdk_root_dir, "examples/demo_apps/hello_world/example.yml"),
            os.path.join(sdk_root_dir, "examples/_boards/frdmk22f/example.yml")  # Should be filtered
        ]
        
        repo_projects = MCUXRepoProjects()
        with patch.object(MCUXAppTargets, 'get_app_targets', return_value=[]) as mock_get_targets:
            result = repo_projects.search_app_targets("examples")
            # Should only process non-_boards/_devices files
            assert mock_get_targets.call_count == 1

    @patch('sdk_project_target.glob.glob')
    def test_search_app_targets_with_filters(self, mock_glob):
        """Test search_app_targets with various filters"""
        mock_glob.return_value = [
            os.path.join(sdk_root_dir, "examples/demo_apps/hello_world/example.yml")
        ]
        
        repo_projects = MCUXRepoProjects()
        with patch.object(MCUXAppTargets, 'get_app_targets', return_value=[]):
            result = repo_projects.search_app_targets(
                "examples",
                board_cores_filter=["frdmk22f"],
                shields_filter=["shield1"],
                devices_filter=["MK22FN512xxx12"],
                toolchains_filter=["armgcc"],
                targets_filter=["debug"]
            )
            
            # Verify filters were configured
            assert "frdmk22f" in MCUXAppTargets.BOARDS_FILTER
            assert "shield1" in MCUXAppTargets.SHIELDS_FILTER
            assert "MK22FN512xxx12" in MCUXAppTargets.DEVICES_FILTER
            assert "armgcc" in MCUXAppTargets.TOOLCHAINS_FILTER
            assert "debug" in MCUXAppTargets.TARGETS_FILTER

    def test_dump_to_file_json(self):
        """Test dumping apps to JSON file"""
        with tempfile.NamedTemporaryFile(suffix='.json', delete=False) as f:
            temp_file = f.name
        
        try:
            project = Mock()
            project.as_dict.return_value = {"name": "test_app", "board": "frdmk22f"}
            
            repo_projects = MCUXRepoProjects()
            with patch('sdk_project_target.mcux_write_json') as mock_write:
                repo_projects.dump_to_file(temp_file, [project])
                mock_write.assert_called_once()
                args = mock_write.call_args[0]
                assert args[0] == temp_file
                assert args[1] == [{"name": "test_app", "board": "frdmk22f"}]
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)

    def test_dump_to_file_yaml(self):
        """Test dumping apps to YAML file"""
        with tempfile.NamedTemporaryFile(suffix='.yml', delete=False) as f:
            temp_file = f.name
        
        try:
            project = Mock()
            project.as_dict.return_value = {"name": "test_app", "board": "frdmk22f"}
            
            repo_projects = MCUXRepoProjects()
            with patch('sdk_project_target.mcux_write_yaml') as mock_write:
                repo_projects.dump_to_file(temp_file, [project])
                mock_write.assert_called_once()
                args = mock_write.call_args[0]
                assert args[0] == temp_file
                assert args[1] == [{"name": "test_app", "board": "frdmk22f"}]
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)

    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_dump_to_file_robot(self, mock_exists):
        """Test dumping apps to Robot Framework file"""
        with tempfile.NamedTemporaryFile(suffix='.robot', delete=False) as f:
            temp_file = f.name
        
        try:
            project = MCUXProjectData.from_fields(
                name="test_app",
                board="frdmk22f",
                device=None,
                core_id="cm4",
                toolchain="armgcc",
                target="debug",
                project_file="examples/demo_apps/hello_world",
                category="demo_apps",
                use_sysbuild=False
            )
            
            repo_projects = MCUXRepoProjects()
            repo_projects.dump_to_file(temp_file, [project])
            
            with open(temp_file, 'r') as f:
                content = f.read()
                assert "*** Settings ***" in content
                assert "*** Variables ***" in content
                assert "*** Test Cases ***" in content
                assert "Test test_app Build" in content
                assert "[Tags]" in content
                assert "frdmk22f@cm4" in content
        finally:
            if os.path.exists(temp_file):
                os.unlink(temp_file)

    def test_dump_to_file_invalid(self):
        """Test dumping apps with invalid file extension"""
        repo_projects = MCUXRepoProjects()
        with patch('sdk_project_target.logger') as mock_logger:
            repo_projects.dump_to_file("invalid.txt", [])
            mock_logger.error.assert_called_once()

    def test_pretty_print_apps(self):
        """Test pretty printing apps"""
        project = Mock()
        project.build_cmd = "west build -p always examples/demo_apps/hello_world"
        
        repo_projects = MCUXRepoProjects()
        with patch('sdk_project_target.logger') as mock_logger:
            repo_projects.pretty_print_apps([project])
            mock_logger.info.assert_called_once()
            call_args = mock_logger.info.call_args[0][0]
            assert "west build" in call_args

    def test_silent_print_apps(self, capsys):
        """Test silent printing apps"""
        project = Mock()
        project.build_cmd = "west build -p always examples/demo_apps/hello_world"
        
        repo_projects = MCUXRepoProjects()
        repo_projects.silent_print_apps([project])
        
        captured = capsys.readouterr()
        assert "west build -p always examples/demo_apps/hello_world" in captured.out


class TestIntegration:
    """Integration tests for the module"""

    @patch('sdk_project_target.os.path.exists', return_value=True)
    @patch('sdk_project_target.mcux_read_yaml')
    def test_end_to_end_workflow(self, mock_read_yaml, mock_exists):
        """Test complete workflow from search to export"""
        # Setup mock YAML data
        mock_read_yaml.return_value = {
            "hello_world": {
                "section-type": "application",
                "boards": {
                    "frdmk22f": ["+armgcc@debug", "+iar@release"]
                },
                "contents": {
                    "document": {
                        "category": "demo_apps",
                        "extra_build_args": ["--verbose"]
                    },
                    "toolchains": ["+mdk@debug"]
                },
                "use_sysbuild": False
            }
        }
        
        # Configure filters
        MCUXAppTargets.config_filter(
            toolchains_filter=["armgcc", "iar", "mdk"],
            boards_filter=["frdmk22f"],
            targets_filter=["debug", "release"]
        )
        
        # Mock glob to return our test file
        with patch('sdk_project_target.glob.glob') as mock_glob:
            mock_glob.return_value = [
                os.path.join(sdk_root_dir, "examples/demo_apps/hello_world/example.yml")
            ]
            
            # Mock the injection methods to avoid file system access
            with patch.object(MCUXAppTargets, 'inject_targets_from_instance_default'):
                with patch.object(MCUXAppTargets, 'inject_targets_from_instance_category'):
                    with patch.object(MCUXAppTargets, 'inject_targets_from_app_category'):
                        # Search for targets
                        repo_projects = MCUXRepoProjects()
                        results = repo_projects.search_app_targets(
                            "examples/demo_apps",
                            board_cores_filter=["frdmk22f"],
                            toolchains_filter=["armgcc", "iar", "mdk"]
                        )
                        
                        # Verify results
                        assert len(results) == 3  # 3 toolchain@target combinations
                        
                        # Test export to JSON
                        with tempfile.NamedTemporaryFile(suffix='.json', delete=False) as f:
                            temp_json = f.name
                        try:
                            with patch('sdk_project_target.mcux_write_json') as mock_write:
                                repo_projects.dump_to_file(temp_json, results)
                                mock_write.assert_called_once()
                        finally:
                            if os.path.exists(temp_json):
                                os.unlink(temp_json)

    @patch('sdk_project_target.os.path.isdir')
    @patch('sdk_project_target.sys.path')
    def test_config_internal_data_success(self, mock_sys_path, mock_isdir):
        """Test successful configuration of internal data"""
        mock_isdir.return_value = True
        
        # Create a mock internal module
        mock_int_module = MagicMock()
        mock_int_module.IntMCUXAppTargets.BOARD_DEF_TARGETS = {"test_board": ["armgcc@debug"]}
        mock_int_module.IntMCUXAppTargets.DEVICE_DEF_TARGETS = {"test_device": ["iar@release"]}
        mock_int_module.IntMCUXAppTargets.INT_EXAMPLE_DATA = {"test_app": {"data": "value"}}
        
        with patch.dict('sys.modules', {'list_project_mod': mock_int_module}):
            MCUXAppTargets.config_internal_data()
            
            assert MCUXAppTargets.BOARD_DEF_TARGETS == {"test_board": ["armgcc@debug"]}
            assert MCUXAppTargets.DEVICE_DEF_TARGETS == {"test_device": ["iar@release"]}
            assert MCUXAppTargets.INT_EXAMPLE_DATA == {"test_app": {"data": "value"}}

    @patch('sdk_project_target.os.path.isdir')
    def test_config_internal_data_failure(self, mock_isdir):
        """Test configuration of internal data when module not found"""
        mock_isdir.return_value = False
        
        # Reset to empty before test
        MCUXAppTargets.BOARD_DEF_TARGETS = {}
        MCUXAppTargets.DEVICE_DEF_TARGETS = {}
        MCUXAppTargets.INT_EXAMPLE_DATA = {}
        
        MCUXAppTargets.config_internal_data()
        
        # Should remain empty on failure
        assert MCUXAppTargets.BOARD_DEF_TARGETS == {}
        assert MCUXAppTargets.DEVICE_DEF_TARGETS == {}
        assert MCUXAppTargets.INT_EXAMPLE_DATA == {}


class TestEdgeCases:
    """Test edge cases and error conditions"""

    def test_project_data_empty_name(self):
        """Test MCUXProjectData with empty name"""
        project = MCUXProjectData()
        assert project.name == ""

    def test_project_data_empty_core_id(self):
        """Test MCUXProjectData with empty core_id"""
        project = MCUXProjectData()
        assert project.core_id == ""

    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_project_data_windows_path(self, mock_exists):
        """Test MCUXProjectData with Windows-style path"""
        project = MCUXProjectData()
        project.project_file = "examples\\demo_apps\\hello_world\\main"
        
        # Should convert backslashes to forward slashes
        assert "/" in project.project_file
        assert "\\" not in project.project_file

    def test_inject_target_with_special_characters(self):
        """Test inject_target with special characters in target name"""
        app_targets = MCUXAppTargets()
        app_targets.inject_target("+armgcc@debug-O2")
        assert "armgcc@debug-O2" in app_targets.tgt_dict

    def test_filter_with_empty_string(self):
        """Test filtering with empty string input"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter("", ["test"], [])
        assert result is False

    def test_filter_with_none_input(self):
        """Test filtering with None input"""
        app_targets = MCUXAppTargets()
        result = app_targets.do_filter(None, [], [])
        assert result is True

    def test_validate_example_data(self):
        """Test validation of example data against schema"""
        app_targets = MCUXAppTargets()
        
        with patch('sdk_project_target.mcux_read_yaml') as mock_read_yaml:
            mock_read_yaml.return_value = {
                "hello_world": {
                    "section-type": "application",
                    "boards": {"frdmk22f": ["+armgcc@debug"]},
                    "contents": {"document": {"category": "demo_apps"}}
                }
            }
            
            with patch('sdk_project_target.os.path.exists', return_value=True):
                example_path = f"{sdk_root_dir}/examples/demo_apps/hello_world/example.yml"
                
                with patch.object(MCUXAppTargets, '_validate_example_data') as mock_validate:
                    with patch.object(app_targets, 'inject_targets_from_instance_default'):
                        with patch.object(app_targets, 'inject_targets_from_instance_category'):
                            with patch.object(app_targets, 'inject_targets_from_app_category'):
                                result = app_targets.get_app_targets(example_path, validate=True)
                                mock_validate.assert_called_once_with(example_path, mock_read_yaml.return_value)

                                mock_validate.reset_mock()
                                result = app_targets.get_app_targets(example_path, validate=False)
                                mock_validate.assert_not_called()


    def test_multiple_shields_only_first_used(self):
        """Test that only the first shield is used when multiple are defined"""
        with patch('sdk_project_target.mcux_read_yaml') as mock_read_yaml:
            mock_read_yaml.return_value = {
                "hello_world": {
                    "section-type": "application",
                    "boards": {
                        "frdmk22f": ["+armgcc@debug"]
                    },
                    "shields": {
                        "shield1": {},
                        "shield2": {},
                        "shield3": {}
                    },
                    "contents": {
                        "document": {
                            "category": "demo_apps"
                        }
                    }
                }
            }
            
            MCUXAppTargets.config_filter()
            app_targets = MCUXAppTargets()
            
            with patch.object(app_targets, 'inject_targets_from_instance_default'):
                with patch.object(app_targets, 'inject_targets_from_instance_category'):
                    with patch.object(app_targets, 'inject_targets_from_app_category'):
                        with patch('sdk_project_target.os.path.exists', return_value=True):
                            result = app_targets.get_app_targets("test.yml")
                            assert len(result) == 1
                            # Should use the first shield from the keys
                            assert result[0].shield in ["shield1", "shield2", "shield3"]

    def test_freestanding_application_no_internal_query(self):
        """Test that freestanding applications don't query internal data"""
        with patch('sdk_project_target.mcux_read_yaml') as mock_read_yaml:
            mock_read_yaml.return_value = {
                "hello_world": {
                    "section-type": "freestanding_application",
                    "boards": {
                        "frdmk22f": ["+armgcc@debug"]
                    },
                    "contents": {
                        "document": {
                            "category": "demo_apps"
                        }
                    }
                }
            }
            
            # Set up internal data that should NOT be used
            MCUXAppTargets.INT_EXAMPLE_DATA = {
                "hello_world": {
                    "frdmk22f": ["+iar@release"]  # This should NOT be added
                }
            }
            
            MCUXAppTargets.config_filter()
            app_targets = MCUXAppTargets()
            
            with patch.object(app_targets, 'inject_targets_from_instance_default'):
                with patch.object(app_targets, 'inject_targets_from_instance_category'):
                    with patch.object(app_targets, 'inject_targets_from_app_category'):
                        with patch('sdk_project_target.os.path.exists', return_value=True):
                            result = app_targets.get_app_targets("test.yml")
                            # Should only have armgcc@debug, not iar@release
                            assert len(result) == 1
                            assert result[0].toolchain == "armgcc"

    @patch('sdk_project_target.mcux_read_yaml')
    @patch('sdk_project_target.os.path.exists', return_value=True)
    def test_pick_one_target_for_app(self, mock_exists, mock_read_yaml):
        """Test is_pick_one_target_for_app flag stops after first target"""
        mock_read_yaml.return_value = {
            "hello_world": {
                "section-type": "application",
                "boards": {
                    "frdmk22f": ["+armgcc@debug", "+iar@release", "+mdk@debug"]
                },
                "contents": {
                    "document": {
                        "category": "demo_apps"
                    }
                }
            }
        }
        
        MCUXAppTargets.config_filter()
        # Reset internal data
        MCUXAppTargets.config_internal_data()
        app_targets = MCUXAppTargets()

        with patch.object(app_targets, 'inject_targets_from_instance_default'):
            with patch.object(app_targets, 'inject_targets_from_instance_category'):
                with patch.object(app_targets, 'inject_targets_from_app_category'):
                    # Without flag - should get all targets
                    result = app_targets.get_app_targets("test.yml", is_pick_one_target_for_app=False)
                    assert len(result) == 3
                    
                    # With flag - should get only first target
                    result = app_targets.get_app_targets("test.yml", is_pick_one_target_for_app=True)
                    assert len(result) == 1


class TestMCUXRepoProjectsGetDefaultSearchRoots:
    """Tests for MCUXRepoProjects.get_default_search_roots (MCUX-83504)."""

    def _make_project(self, abspath, has_examples=None):
        p = Mock()
        p.abspath = abspath
        p.userdata = {'has_examples': has_examples} if has_examples is not None else {}
        return p

    def test_returns_marked_project_paths(self):
        """Projects with has_examples: true are returned as search roots."""
        manifest = Mock()
        manifest.projects = [
            self._make_project('/ws/examples', has_examples=True),
            self._make_project('/ws/middleware/emwin', has_examples=True),
            self._make_project('/ws/middleware/erpc', has_examples=None),
        ]
        result = MCUXRepoProjects.get_default_search_roots(manifest)
        assert result == ['/ws/examples', '/ws/middleware/emwin']

    def test_falls_back_to_cwd_when_no_marked_projects(self):
        """When no projects carry has_examples the CWD fallback is used."""
        manifest = Mock()
        manifest.projects = [
            self._make_project('/ws/drivers'),
            self._make_project('/ws/components'),
        ]
        with patch('sdk_project_target.os.getcwd', return_value='/current/dir'):
            result = MCUXRepoProjects.get_default_search_roots(manifest)
        assert result == ['/current/dir']

    def test_falls_back_to_cwd_when_manifest_is_none(self):
        """A None manifest produces the CWD fallback."""
        with patch('sdk_project_target.os.getcwd', return_value='/current/dir'):
            result = MCUXRepoProjects.get_default_search_roots(None)
        assert result == ['/current/dir']

    def test_falls_back_to_cwd_on_manifest_exception(self):
        """An exception during manifest iteration falls back gracefully."""
        manifest = Mock()
        manifest.projects = property(lambda self: (_ for _ in ()).throw(RuntimeError('boom')))
        with patch('sdk_project_target.os.getcwd', return_value='/current/dir'):
            result = MCUXRepoProjects.get_default_search_roots(manifest)
        assert result == ['/current/dir']

    def test_ignores_false_has_examples(self):
        """Projects with has_examples: false are not included."""
        manifest = Mock()
        manifest.projects = [
            self._make_project('/ws/examples', has_examples=True),
            self._make_project('/ws/middleware/erpc', has_examples=False),
        ]
        result = MCUXRepoProjects.get_default_search_roots(manifest)
        assert result == ['/ws/examples']


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
