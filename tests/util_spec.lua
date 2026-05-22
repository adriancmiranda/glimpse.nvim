local util = require('glimpse.util')

describe('util', function()
	local cert_dir = vim.fn.tempname()
	vim.fn.mkdir(cert_dir, 'p')

	describe('is_image', function()
		it('returns true for supported extensions', function()
			assert.is_true(util.is_image('/path/to/photo.png'))
			assert.is_true(util.is_image('/path/to/photo.jpg'))
			assert.is_true(util.is_image('/path/to/photo.jpeg'))
			assert.is_true(util.is_image('/path/to/photo.gif'))
			assert.is_true(util.is_image('/path/to/photo.bmp'))
			assert.is_true(util.is_image('/path/to/photo.webp'))
			assert.is_true(util.is_image('/path/to/photo.avif'))
			assert.is_true(util.is_image('/path/to/photo.svg'))
			assert.is_true(util.is_image('/path/to/photo.pdf'))
			assert.is_true(util.is_image('/path/to/photo.pict'))
		end)

		it('returns true regardless of case', function()
			assert.is_true(util.is_image('/path/to/PHOTO.PNG'))
			assert.is_true(util.is_image('/path/to/Photo.Jpg'))
			assert.is_true(util.is_image('/path/to/IMAGE.WEBP'))
		end)

		it('returns false for non-image extensions', function()
			assert.is_false(util.is_image('/path/to/file.lua'))
			assert.is_false(util.is_image('/path/to/file.txt'))
			assert.is_false(util.is_image('/path/to/file.md'))
			assert.is_false(util.is_image('/path/to/file.rs'))
		end)

		it('returns false for files without extension', function()
			assert.is_false(util.is_image('/path/to/Makefile'))
			assert.is_false(util.is_image('noext'))
		end)

		it('returns false for dotfiles', function()
			assert.is_false(util.is_image('/path/to/.gitignore'))
		end)
	end)

	describe('is_video', function()
		it('returns true for supported video extensions', function()
			assert.is_true(util.is_video('/path/to/video.mp4'))
			assert.is_true(util.is_video('/path/to/video.mkv'))
			assert.is_true(util.is_video('/path/to/video.avi'))
			assert.is_true(util.is_video('/path/to/video.mov'))
			assert.is_true(util.is_video('/path/to/video.webm'))
			assert.is_true(util.is_video('/path/to/video.flv'))
			assert.is_true(util.is_video('/path/to/video.wmv'))
			assert.is_true(util.is_video('/path/to/video.m4v'))
		end)

		it('returns true regardless of case', function()
			assert.is_true(util.is_video('/path/to/VIDEO.MP4'))
			assert.is_true(util.is_video('/path/to/Movie.MKV'))
		end)

		it('returns false for image extensions', function()
			assert.is_false(util.is_video('/path/to/photo.png'))
			assert.is_false(util.is_video('/path/to/photo.jpg'))
		end)

		it('returns false for non-media extensions', function()
			assert.is_false(util.is_video('/path/to/file.lua'))
			assert.is_false(util.is_video('/path/to/file.txt'))
		end)

		it('returns false for files without extension', function()
			assert.is_false(util.is_video('/path/to/Makefile'))
		end)
	end)

	describe('is_previewable', function()
		it('returns true for images', function()
			assert.is_true(util.is_previewable('/path/to/photo.png'))
			assert.is_true(util.is_previewable('/path/to/photo.jpg'))
		end)

		it('returns true for videos', function()
			assert.is_true(util.is_previewable('/path/to/video.mp4'))
			assert.is_true(util.is_previewable('/path/to/video.mkv'))
		end)

		it('returns true for certificates', function()
			local cert = cert_dir .. '/cert.pem'
			vim.fn.writefile({
				'-----BEGIN CERTIFICATE-----',
				'MIIBezCCASWgAwIBAgIUT3',
				'-----END CERTIFICATE-----',
			}, cert)
			assert.is_true(util.is_previewable(cert))
		end)

		it('returns false for non-media files', function()
			assert.is_false(util.is_previewable('/path/to/file.lua'))
			assert.is_false(util.is_previewable('/path/to/file.txt'))
		end)
	end)

	describe('is_cert', function()
		it('returns true for crt files', function()
			assert.is_true(util.is_cert('/path/to/cert.crt'))
		end)

		it('returns true for pem certificate files', function()
			local cert = cert_dir .. '/cert.pem'
			vim.fn.writefile({
				'-----BEGIN CERTIFICATE-----',
				'MIIBezCCASWgAwIBAgIUT3',
				'-----END CERTIFICATE-----',
			}, cert)
			assert.is_true(util.is_cert(cert))
		end)

		it('returns true for pem bundle files with certificate headers after comments', function()
			local cert = cert_dir .. '/bundle.pem'
			vim.fn.writefile({
				'# Issuer: CN=Example Root CA',
				'# Subject: CN=Example Root CA',
				'# Label: "Example Root CA"',
				'-----BEGIN CERTIFICATE-----',
				'MIIBezCCASWgAwIBAgIUT3',
				'-----END CERTIFICATE-----',
			}, cert)
			assert.is_true(util.is_cert(cert))
		end)

		it('returns false for pem key files', function()
			local key = cert_dir .. '/key.pem'
			vim.fn.writefile({
				'-----BEGIN RSA PRIVATE KEY-----',
				'MIIEpAIBAAKCAQE',
				'-----END RSA PRIVATE KEY-----',
			}, key)
			assert.is_false(util.is_cert(key))
		end)
	end)

	describe('is_key', function()
		it('returns true for pem key files', function()
			local key = cert_dir .. '/key.pem'
			vim.fn.writefile({
				'-----BEGIN RSA PRIVATE KEY-----',
				'MIIEpAIBAAKCAQE',
				'-----END RSA PRIVATE KEY-----',
			}, key)
			assert.is_true(util.is_key(key))
		end)

		it('returns false for pem certificate files', function()
			local cert = cert_dir .. '/cert.pem'
			vim.fn.writefile({
				'-----BEGIN CERTIFICATE-----',
				'MIIBezCCASWgAwIBAgIUT3',
				'-----END CERTIFICATE-----',
			}, cert)
			assert.is_false(util.is_key(cert))
		end)
	end)
end)
