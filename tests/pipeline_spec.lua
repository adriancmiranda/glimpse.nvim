local pipeline = require('glimpse.pipeline')

local function stub_fn(table_ref, key, value)
	local original = table_ref[key]
	table_ref[key] = value
	return original
end

describe('pipeline', function()
	local calls
	local restore = {}

	before_each(function()
		calls = {
			jobstart = {},
			jobstop = {},
			notify = {},
			executable = {},
			tempname = 0,
			mkdir = {},
			deleted = {},
			removed = {},
		}

		restore.executable = stub_fn(vim.fn, 'executable', function(cmd)
			if calls.executable_result then
				return calls.executable_result[cmd] or 0
			end
			return 1
		end)

		restore.jobstart = stub_fn(vim.fn, 'jobstart', function(cmd, opts)
			local id = #calls.jobstart + 1
			calls.jobstart[id] = { cmd = cmd, opts = opts }
			return calls.jobstart_result or id
		end)

		restore.jobstop = stub_fn(vim.fn, 'jobstop', function(id)
			calls.jobstop[#calls.jobstop + 1] = id
		end)

		restore.notify = stub_fn(vim, 'notify', function(msg, level)
			calls.notify[#calls.notify + 1] = { msg = msg, level = level }
		end)

		restore.schedule = stub_fn(vim, 'schedule', function(fn)
			fn()
		end)

		restore.tempname = stub_fn(vim.fn, 'tempname', function()
			calls.tempname = calls.tempname + 1
			return '/tmp/glimpse_test_' .. calls.tempname
		end)

		restore.mkdir = stub_fn(vim.fn, 'mkdir', function(path, _flags)
			calls.mkdir[#calls.mkdir + 1] = path
		end)

		restore.fs_stat = stub_fn(vim.uv, 'fs_stat', function()
			if calls.output_exists == false then
				return nil
			end
			return { type = 'file', size = 1 }
		end)

		restore.delete = stub_fn(vim.fn, 'delete', function(path, flags)
			calls.deleted[#calls.deleted + 1] = { path = path, flags = flags }
		end)

		restore.remove = rawget(os, 'remove')
		rawset(os, 'remove', function(path)
			calls.removed[#calls.removed + 1] = path
			return true
		end)
	end)

	after_each(function()
		vim.fn.executable = restore.executable
		vim.fn.jobstart = restore.jobstart
		vim.fn.jobstop = restore.jobstop
		vim.notify = restore.notify
		vim.schedule = restore.schedule
		vim.fn.tempname = restore.tempname
		vim.fn.mkdir = restore.mkdir
		vim.uv.fs_stat = restore.fs_stat
		vim.fn.delete = restore.delete
		rawset(os, 'remove', restore.remove)
	end)

	local function fire_exit(job_id, code)
		calls.jobstart[job_id].opts.on_exit(job_id, code)
	end

	describe('M.resolve_config', function()
		it('prefers an extension-specific pipeline over the type pipeline', function()
			local by_type = { steps = { { command = 'f3d' } } }
			local by_extension = { previewers = { { command = 'blender' } } }
			local configs = {
				model = by_type,
				['.blend'] = by_extension,
			}

			assert.equals(by_extension, pipeline.resolve_config(configs, 'model', '/tmp/SCENE.BLEND'))
			assert.equals(by_type, pipeline.resolve_config(configs, 'model', '/tmp/model.obj'))
		end)
	end)

	describe('M.run_steps', function()
		it('calls on_done with {path} when single static step succeeds', function()
			local result, err
			local cfg = {
				steps = {
					{ command = 'magick', args = { '{input}', '{output}' } },
				},
			}
			pipeline.run_steps(cfg, '/in/file.svg', function(r, e)
				result, err = r, e
			end)
			assert.equals(1, #calls.jobstart)
			assert.same({ 'magick', '/in/file.svg', '/tmp/glimpse_test_1.png' }, calls.jobstart[1].cmd)
			fire_exit(1, 0)
			assert.is_not_nil(result)
			assert.equals('/tmp/glimpse_test_1.png', result.path)
			assert.is_nil(err)
		end)

		it('resolves {input} and {output} placeholders', function()
			local cfg = {
				steps = {
					{ command = 'conv', args = { '--in', '{input}', '--out', '{output}', '--extra' } },
				},
			}
			pipeline.run_steps(cfg, '/src.obj', function() end)
			assert.same({ 'conv', '--in', '/src.obj', '--out', '/tmp/glimpse_test_1.png', '--extra' }, calls.jobstart[1].cmd)
		end)

		it('accepts args as a function', function()
			local cfg = {
				steps = {
					{
						command = 'f3d',
						args = function(input, output)
							return { input, '--output', output, '--config=thumbnail' }
						end,
					},
				},
			}
			pipeline.run_steps(cfg, '/model.obj', function() end)
			assert.same(
				{ 'f3d', '/model.obj', '--output', '/tmp/glimpse_test_1.png', '--config=thumbnail' },
				calls.jobstart[1].cmd
			)
		end)

		it('uses output_ext from step', function()
			local cfg = {
				steps = {
					{ command = 'rsvg-convert', args = { '{input}', '-o', '{output}' }, output_ext = '.svg' },
				},
			}
			pipeline.run_steps(cfg, '/in/file.svg', function() end)
			-- cmd = { 'rsvg-convert', '/in/file.svg', '-o', '/tmp/.../....svg' }
			assert.is_not_nil(calls.jobstart[1].cmd[4]:match('%.svg$'))
		end)

		it('returns error when step fails', function()
			local result, err
			local cfg = {
				steps = { { command = 'tool_a', args = {} } },
			}
			pipeline.run_steps(cfg, '/in/file', function(r, e)
				result, err = r, e
			end)
			fire_exit(1, 2)
			assert.is_nil(result)
			assert.is_not_nil(err)
		end)

		it('returns error when a successful command produces no output', function()
			calls.output_exists = false
			local result, err
			local cfg = {
				steps = { { command = 'silent_tool', args = {} } },
			}
			pipeline.run_steps(cfg, '/in/file', function(r, e)
				result, err = r, e
			end)
			fire_exit(1, 0)

			assert.is_nil(result)
			assert.matches('did not produce output', err)
		end)

		it('returns error when command is not executable', function()
			calls.executable_result = { missing_tool = 0 }
			local result, err
			local cfg = {
				steps = { { command = 'missing_tool', args = {} } },
			}
			pipeline.run_steps(cfg, '/in/file', function(r, e)
				result, err = r, e
			end)
			assert.is_nil(result)
			assert.is_not_nil(err)
		end)

		it('returns error when no steps configured', function()
			local result, err
			pipeline.run_steps({}, '/in/file', function(r, e)
				result, err = r, e
			end)
			assert.is_nil(result)
			assert.is_not_nil(err)
		end)

		it('tries previewers in order until one succeeds', function()
			local result, err
			local cfg = {
				previewers = {
					{ command = 'first', args = { '{input}', '{output}' } },
					{ command = 'second', args = { '{input}', '{output}' } },
				},
			}
			pipeline.run_steps(cfg, '/in/file', function(r, e)
				result, err = r, e
			end)

			assert.equals('first', calls.jobstart[1].cmd[1])
			fire_exit(1, 2)
			assert.equals('second', calls.jobstart[2].cmd[1])
			fire_exit(2, 0)

			assert.is_nil(err)
			assert.equals('/tmp/glimpse_test_2.png', result.path)
			assert.equals('/tmp/glimpse_test_1.png', calls.removed[1])
		end)

		it('skips missing previewers before trying the next one', function()
			calls.executable_result = { first = 0, second = 1 }
			local result
			pipeline.run_steps(
				{
					previewers = {
						{ command = 'first', args = {} },
						{ command = 'second', args = { '{input}', '{output}' } },
					},
				},
				'/in/file',
				function(r)
					result = r
				end
			)

			assert.equals(1, #calls.jobstart)
			assert.equals('second', calls.jobstart[1].cmd[1])
			fire_exit(1, 0)
			assert.is_not_nil(result)
		end)

		it('reports every previewer failure when none succeed', function()
			local result, err
			pipeline.run_steps(
				{
					previewers = {
						{ command = 'first', args = {} },
						{ command = 'second', args = {} },
					},
				},
				'/in/file',
				function(r, e)
					result, err = r, e
				end
			)
			fire_exit(1, 1)
			fire_exit(2, 2)

			assert.is_nil(result)
			assert.matches('first exited with code 1', err)
			assert.matches('second exited with code 2', err)
		end)

		it('cancel stops in-flight job', function()
			local cfg = {
				steps = { { command = 'slow_tool', args = { '{input}', '{output}' } } },
			}
			local cancel = pipeline.run_steps(cfg, '/in/file', function() end)
			cancel()
			assert.equals(1, #calls.jobstop)
			assert.equals(1, calls.jobstop[1])
			assert.equals('/tmp/glimpse_test_1.png', calls.removed[1])
		end)

		it('returns an error when jobstart cannot start the command', function()
			calls.jobstart_result = 0
			local result, err
			local cfg = {
				steps = { { command = 'broken_tool', args = { '{input}', '{output}' } } },
			}
			pipeline.run_steps(cfg, '/in/file', function(r, e)
				result, err = r, e
			end)

			assert.is_nil(result)
			assert.matches('failed to start job', err)
			assert.equals('/tmp/glimpse_test_1.png', calls.removed[1])
		end)

		it('chains two static steps: first output becomes second input', function()
			local result
			local cfg = {
				steps = {
					{ command = 'step_a', args = { '{input}', '{output}' } },
					{ command = 'step_b', args = { '{input}', '{output}' } },
				},
			}
			pipeline.run_steps(cfg, '/src.obj', function(r, _)
				result = r
			end)
			assert.equals(1, #calls.jobstart)
			fire_exit(1, 0)
			-- step_b should receive step_a's output as input
			assert.equals(2, #calls.jobstart)
			assert.equals('/tmp/glimpse_test_1.png', calls.jobstart[2].cmd[2])
			fire_exit(2, 0)
			assert.is_not_nil(result)
			assert.equals('/tmp/glimpse_test_2.png', result.path)
			assert.equals('/tmp/glimpse_test_1.png', calls.removed[1])
			result.cleanup()
			assert.equals('/tmp/glimpse_test_2.png', calls.removed[2])
		end)

		it('second step receives fps as third arg', function()
			local received_fps
			local cfg = {
				steps = {
					{ command = 'step_a', args = { '{input}', '{output}' } },
					{
						command = 'step_b',
						output_ext = '.gif',
						args = function(_input, _output, fps)
							received_fps = fps
							return { 'stub' }
						end,
					},
				},
				renderer = { fps = 24 },
			}
			pipeline.run_steps(cfg, '/src.obj', function() end)
			fire_exit(1, 0)
			assert.equals(24, received_fps)
		end)

		it('sequence step returns {frames, tmpdir} when terminal', function()
			local result
			local cfg = {
				steps = {
					{ command = 'f3d', type = 'sequence', frames = 2, args = { '{input}', '{output}' } },
				},
			}
			pipeline.run_steps(cfg, '/m.obj', function(r, _)
				result = r
			end)
			fire_exit(1, 0)
			fire_exit(2, 0)
			assert.is_not_nil(result)
			assert.equals(2, #result.frames)
			assert.is_not_nil(result.tmpdir)
			result.cleanup()
			assert.same({ path = result.tmpdir, flags = 'rf' }, calls.deleted[1])
		end)

		it('sequence step passes tmpdir to next step', function()
			local cfg = {
				steps = {
					{ command = 'f3d', type = 'sequence', frames = 1, args = { '{input}', '{output}' } },
					{ command = 'ffmpeg', output_ext = '.gif', args = { '{input}', '{output}' } },
				},
			}
			pipeline.run_steps(cfg, '/m.obj', function() end)
			fire_exit(1, 0)
			-- ffmpeg receives the tmpdir as input
			assert.equals('/tmp/glimpse_test_1', calls.jobstart[2].cmd[2])
			fire_exit(2, 0)
			assert.same({ path = '/tmp/glimpse_test_1', flags = 'rf' }, calls.deleted[1])
		end)
	end)

	describe('M.run_sequence', function()
		it('generates N frames sequentially', function()
			local frames, err
			local entry = {
				command = 'f3d',
				frames = 3,
				args = function(input, output, frame)
					return { input, '--output', output, '--camera-azimuth-angle=' .. (frame * 120) }
				end,
			}
			pipeline.run_sequence(entry, '/model.obj', '/tmp/seq', function(f, e)
				frames, err = f, e
			end)

			assert.equals(1, #calls.jobstart)
			fire_exit(1, 0)
			assert.equals(2, #calls.jobstart)
			fire_exit(2, 0)
			assert.equals(3, #calls.jobstart)
			fire_exit(3, 0)

			assert.is_nil(err)
			assert.equals(3, #frames)
			assert.equals('/tmp/seq/frame_0001.png', frames[1])
			assert.equals('/tmp/seq/frame_0002.png', frames[2])
			assert.equals('/tmp/seq/frame_0003.png', frames[3])
		end)

		it('passes 0-based frame index to args function', function()
			local entry = {
				command = 'f3d',
				frames = 2,
				args = function(input, output, frame)
					return { input, '--output', output, tostring(frame) }
				end,
			}
			pipeline.run_sequence(entry, '/m.obj', '/tmp/s', function() end)
			fire_exit(1, 0)
			fire_exit(2, 0)

			assert.same({ 'f3d', '/m.obj', '--output', '/tmp/s/frame_0001.png', '0' }, calls.jobstart[1].cmd)
			assert.same({ 'f3d', '/m.obj', '--output', '/tmp/s/frame_0002.png', '1' }, calls.jobstart[2].cmd)
		end)

		it('aborts and returns error on frame failure', function()
			local frames, err
			local entry = { command = 'f3d', frames = 3, args = { '{input}', '{output}' } }
			pipeline.run_sequence(entry, '/m.obj', '/tmp/s', function(f, e)
				frames, err = f, e
			end)
			fire_exit(1, 1)
			assert.is_nil(frames)
			assert.is_not_nil(err)
			assert.equals(1, #calls.jobstart)
		end)

		it('defaults to 36 frames when entry.frames is nil', function()
			local done_frames
			local entry = { command = 'f3d', args = { '{input}', '{output}' } }
			pipeline.run_sequence(entry, '/m.obj', '/tmp/s', function(f, _)
				done_frames = f
			end)
			for i = 1, 36 do
				fire_exit(i, 0)
			end
			assert.equals(36, #calls.jobstart)
			assert.equals(36, #done_frames)
		end)

		it('cancel stops in-flight frame job', function()
			local entry = { command = 'f3d', frames = 5, args = { '{input}', '{output}' } }
			local cancel = pipeline.run_sequence(entry, '/m.obj', '/tmp/s', function() end)
			cancel()
			assert.equals(1, #calls.jobstop)
		end)
	end)
end)
