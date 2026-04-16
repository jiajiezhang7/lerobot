#!/usr/bin/env python

# Copyright 2026 The HuggingFace Inc. team. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
from unittest.mock import patch

from lerobot.policies.factory import make_pre_post_processors
from lerobot.policies.pi0_fast.configuration_pi0_fast import PI0FastConfig


@patch("lerobot.processor.tokenizer_processor.AutoTokenizer")
@patch("lerobot.processor.tokenizer_processor.AutoProcessor")
def test_make_pretrained_pi0_fast_processor_uses_current_local_tokenizer_paths(
    mock_auto_processor, mock_auto_tokenizer, tmp_path
):
    """Loading pretrained Pi0-Fast processors should follow the current config tokenizer paths."""
    mock_auto_processor.from_pretrained.return_value = object()
    mock_auto_tokenizer.from_pretrained.return_value = object()

    preprocessor_config = {
        "name": "policy_preprocessor",
        "steps": [
            {
                "registry_name": "tokenizer_processor",
                "config": {
                    "tokenizer_name": "google/paligemma-3b-pt-224",
                    "max_length": 200,
                    "task_key": "task",
                    "padding_side": "right",
                    "padding": "max_length",
                    "truncation": True,
                },
            },
            {
                "registry_name": "action_tokenizer_processor",
                "config": {
                    "action_tokenizer_name": "lerobot/fast-action-tokenizer",
                    "paligemma_tokenizer_name": "google/paligemma-3b-pt-224",
                    "max_action_tokens": 256,
                    "fast_skip_tokens": 128,
                    "trust_remote_code": True,
                },
            },
        ],
    }
    postprocessor_config = {"name": "policy_postprocessor", "steps": []}

    (tmp_path / "policy_preprocessor.json").write_text(json.dumps(preprocessor_config))
    (tmp_path / "policy_postprocessor.json").write_text(json.dumps(postprocessor_config))

    config = PI0FastConfig()
    config.text_tokenizer_name = str(tmp_path / "local-paligemma")
    config.action_tokenizer_name = str(tmp_path / "local-fast-tokenizer")

    preprocessor, _ = make_pre_post_processors(config, pretrained_path=str(tmp_path))

    assert preprocessor.steps[0].tokenizer_name == config.text_tokenizer_name
    assert preprocessor.steps[1].action_tokenizer_name == config.action_tokenizer_name
    assert preprocessor.steps[1].paligemma_tokenizer_name == config.text_tokenizer_name
