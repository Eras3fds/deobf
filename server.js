// Load environment variables from .env file
require('dotenv').config();

const { Client, GatewayIntentBits, AttachmentBuilder } = require('discord.js');
const { spawn } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
    ]
});

const CONFIG = {
    TOKEN: process.env.DISCORD_TOKEN,
    MAX_FILE_SIZE: parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024,
    ALLOWED_CHANNELS: process.env.ALLOWED_CHANNELS?.split(',') || [],
    LUA_PATH: process.env.LUA_PATH || 'luajit',
    CLI_PATH: path.join(__dirname, 'cli.lua'),
    TEMP_DIR: path.join(os.tmpdir(), 'prometheus-deob'),
    PORT: parseInt(process.env.PORT) || 10000,
};

// Ensure temp directory exists
(async () => {
    try {
        await fs.mkdir(CONFIG.TEMP_DIR, { recursive: true });
        console.log(`📁 Temp directory ready: ${CONFIG.TEMP_DIR}`);
    } catch (e) {
        console.error('Failed to create temp dir:', e);
    }
})();

client.once('ready', () => {
    console.log(`🤖 Bot ready! Logged in as ${client.user.tag}`);
    console.log(`📁 Temp directory: ${CONFIG.TEMP_DIR}`);
    console.log(`📡 Port: ${CONFIG.PORT}`);
});

client.on('messageCreate', async (message) => {
    // Only respond to commands in allowed channels
    if (CONFIG.ALLOWED_CHANNELS.length > 0 && !CONFIG.ALLOWED_CHANNELS.includes(message.channelId)) {
        return;
    }

    if (message.author.bot) return;

    // Command: !deobfuscate with attachment
    if (message.content.startsWith('!deobfuscate')) {
        const attachment = message.attachments.first();
        
        if (!attachment) {
            return message.reply('❌ Please attach a `.lua` file to deobfuscate.');
        }

        if (!attachment.name.endsWith('.lua')) {
            return message.reply('❌ Only `.lua` files are supported.');
        }

        if (attachment.size > CONFIG.MAX_FILE_SIZE) {
            return message.reply(`❌ File too large. Max size: ${CONFIG.MAX_FILE_SIZE / 1024 / 1024}MB`);
        }

        try {
            await message.reply('🔄 Deobfuscating... This may take a moment.');

            const result = await deobfuscateFile(attachment.url, attachment.name);
            
            if (result.success) {
                const outputFile = new AttachmentBuilder(result.outputPath, { name: 'deobfuscated.lua' });
                await message.reply({
                    content: '✅ Deobfuscation complete!',
                    files: [outputFile]
                });
                
                // Cleanup temp file
                await fs.unlink(result.outputPath).catch(() => {});
            } else {
                await message.reply(`❌ Deobfuscation failed:\n\`\`\`\n${result.error}\n\`\`\``);
            }
        } catch (error) {
            console.error('Processing error:', error);
            await message.reply(`❌ Processing error:\n\`\`\`\n${error.message}\n\`\`\``);
        }
    }

    // Help command
    if (message.content === '!help' || message.content === '!deobfuscate help') {
        await message.reply(
            '**Prometheus Deobfuscator Bot**\n\n' +
            '**Usage:**\n' +
            '`!deobfuscate` + attach `.lua` file\n\n' +
            '**Features:**\n' +
            '• Removes Vmify VM\n' +
            '• Decrypts strings\n' +
            '• Resolves constant arrays\n' +
            '• Rebuilds split strings\n' +
            '• Simplifies number expressions\n' +
            '• Unwraps proxy objects\n' +
            '• Removes anti-tamper & watermarks\n\n' +
            `**Max file size:** ${CONFIG.MAX_FILE_SIZE / 1024 / 1024}MB\n` +
            `**Allowed channels:** ${CONFIG.ALLOWED_CHANNELS.length > 0 ? CONFIG.ALLOWED_CHANNELS.join(', ') : 'All channels'}\n\n` +
            '⚠️ **WARNING**: This runs in UNSAFE MODE. Only use on trusted scripts.'
        );
    }
});

/**
 * Deobfuscate a Lua file using cli.lua
 */
async function deobfuscateFile(url, originalName) {
    const inputPath = path.join(CONFIG.TEMP_DIR, `${Date.now()}_${originalName}`);
    const outputPath = inputPath.replace('.lua', '_deobfuscated.lua');

    try {
        // Download file
        console.log(`📥 Downloading: ${url}`);
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const buffer = await response.arrayBuffer();
        await fs.writeFile(inputPath, Buffer.from(buffer));
        console.log(`📄 Saved to: ${inputPath}`);

        // Execute deobfuscator
        console.log('🔄 Running deobfuscator...');
        const result = await new Promise((resolve) => {
            const luaProcess = spawn(CONFIG.LUA_PATH, [
                CONFIG.CLI_PATH,
                inputPath,
                outputPath,
                '--verbose'
            ], {
                cwd: __dirname,
                timeout: 60000,
            });

            let stdout = '';
            let stderr = '';

            luaProcess.stdout.on('data', (data) => {
                stdout += data.toString();
                if (CONFIG.verbose) console.log(`[LUA] ${data.toString().trim()}`);
            });

            luaProcess.stderr.on('data', (data) => {
                stderr += data.toString();
                console.error(`[LUA-ERR] ${data.toString().trim()}`);
            });

            luaProcess.on('close', (code) => {
                resolve({ code, stdout, stderr });
            });

            luaProcess.on('error', (err) => {
                resolve({ code: -1, error: err.message });
            });
        });

        // Check output
        try {
            await fs.access(outputPath);
            const stats = await fs.stat(outputPath);
            console.log(`✅ Output ready: ${outputPath} (${stats.size} bytes)`);
            return {
                success: true,
                outputPath,
                logs: result.stderr
            };
        } catch {
            return {
                success: false,
                error: result.stderr || 'No output generated'
            };
        }
    } finally {
        // Cleanup input
        try {
            await fs.unlink(inputPath);
            console.log(`🗑️  Cleaned: ${inputPath}`);
        } catch {}
    }
}

// Health check endpoint for Render
const http = require('http');
http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('OK');
    } else {
        res.writeHead(404);
        res.end();
    }
}).listen(CONFIG.PORT, () => {
    console.log(`🩺 Health check listening on port ${CONFIG.PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
    console.log('SIGTERM received, shutting down...');
    await client.destroy();
    process.exit(0);
});

client.login(CONFIG.TOKEN).then(() => {
    console.log('🎮 Bot is online and ready!');
}).catch(err => {
    console.error('❌ Failed to login:', err);
    process.exit(1);
});
