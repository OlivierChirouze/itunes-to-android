/*
This script reads the iTunes library and prompts to delete MP3/M4A files in referenced directories that are not part of the library.
*/

import itunes from "itunes-data";
import * as fs from "fs";
import { ReadStream } from "fs";
import path from "path";
import * as readline from "readline";
import { fileURLToPath } from "url";

const libraryPath = path.join(__dirname, 'tmp', 'Library.xml');

function init(): { parser: NodeJS.WritableStream, stream: ReadStream } {
    return {
        parser: itunes.parser(),
        stream: fs.createReadStream(libraryPath)
    }
}

interface Track {
    Location: string;
}

function toPath(url: string): string {
    return fileURLToPath(url);
}

function pathKey(filePath: string): string {
    return filePath.normalize('NFC');
}

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function answerPrompt(prompt: string): Promise<string> {
    return new Promise((resolve) => {
        rl.question(`${prompt} `, resolve);
    });
}

function replaceLastLine(text: string): void {
    if (process.stdout.isTTY) {
        readline.moveCursor(process.stdout, 0, -1);
        readline.clearLine(process.stdout, 0);
        readline.cursorTo(process.stdout, 0);
    }

    process.stdout.write(`${text}\n`);
}

function shouldDelete(answer: string): boolean {
    const normalized = answer.trim().toLowerCase();
    return normalized === '' || normalized === 'y' || normalized === 'yes';
}

async function promptToDelete(fileName: string, filePath: string): Promise<void> {
    const prompt = `  ${fileName} delete [Yn]`;
    const answer = await answerPrompt(prompt);

    if (!shouldDelete(answer)) {
        replaceLastLine(`${prompt} skipped`);
        return;
    }

    try {
        fs.unlinkSync(filePath);
        replaceLastLine(`${prompt} deleted`);
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        replaceLastLine(`${prompt} failed (${message})`);
    }
}

const run = init();
const libraryPaths = new Set<string>();
const referencedDirs = new Map<string, string>();

run.parser.on("track", (track: Track) => {
    const trackPath = toPath(track.Location);
    libraryPaths.add(pathKey(trackPath));
    const dir = path.dirname(trackPath);
    const dirKey = pathKey(dir);
    const existingDir = referencedDirs.get(dirKey);

    if (existingDir === undefined || (!fs.existsSync(existingDir) && fs.existsSync(dir))) {
        referencedDirs.set(dirKey, dir);
    }
});

run.parser.on("end", async () => {
    console.log(`Found ${libraryPaths.size} tracks in ${referencedDirs.size} directories`);

    // For each referenced directory, check for MP3/M4A files not in library
    for (const dir of referencedDirs.values()) {
        if (!fs.existsSync(dir)) {
            console.log(`Directory not found: ${dir}`);
            continue;
        }

        try {
            const files = fs.readdirSync(dir)
                .filter(file => file.endsWith('.mp3') || file.endsWith('.m4a'))
                .map(file => ({
                    name: file,
                    path: path.join(dir, file)
                }))
                .filter(file => !libraryPaths.has(pathKey(file.path)));

            if (files.length > 0) {
                console.log(`\nDirectory: ${dir}`);
                for (const file of files) {
                    await promptToDelete(file.name, file.path);
                }
            }
        } catch (error) {
            console.error(`Error reading directory ${dir}: ${error}`);
        }
    }

    rl.close();
});

run.stream.pipe(run.parser);
