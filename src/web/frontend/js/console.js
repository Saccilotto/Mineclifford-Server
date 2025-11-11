/**
 * Console Terminal Manager
 * Handles WebSocket connection and xterm.js terminal
 */
class ConsoleTerminal {
    constructor(serverId) {
        this.serverId = serverId;
        this.term = null;
        this.ws = null;
        this.api = new MinecliffordAPI();
    }

    /**
     * Initialize terminal
     */
    init() {
        const container = document.getElementById('terminal-container');
        container.innerHTML = '';

        // Create xterm.js terminal
        this.term = new Terminal({
            cursorBlink: true,
            fontSize: 14,
            fontFamily: 'Monaco, Menlo, "Ubuntu Mono", monospace',
            theme: {
                background: '#000000',
                foreground: '#ffffff',
                cursor: '#ffffff',
                black: '#000000',
                red: '#ff0000',
                green: '#00ff00',
                yellow: '#ffff00',
                blue: '#0000ff',
                magenta: '#ff00ff',
                cyan: '#00ffff',
                white: '#ffffff',
            },
            rows: 24,
            cols: 100
        });

        this.term.open(container);

        // Welcome message
        this.term.writeln('\x1b[1;32mMineclifford Server Console\x1b[0m');
        this.term.writeln('\x1b[1;34m' + '='.repeat(50) + '\x1b[0m');
        this.term.writeln(`Server ID: ${this.serverId}`);
        this.term.writeln('\x1b[1;34m' + '='.repeat(50) + '\x1b[0m');
        this.term.writeln('');

        // Connect WebSocket
        this.connect();

        // Handle input
        this.setupInput();
    }

    /**
     * Connect to WebSocket
     */
    connect() {
        this.term.writeln('Connecting to server console...');

        try {
            this.ws = this.api.createConsoleWebSocket(this.serverId);

            this.ws.onopen = () => {
                this.term.writeln('\x1b[1;32mConnected!\x1b[0m');
                this.term.writeln('Type commands and press Enter');
                this.term.writeln('');
            };

            this.ws.onmessage = (event) => {
                this.term.write(event.data);
            };

            this.ws.onerror = (error) => {
                this.term.writeln('\x1b[1;31mWebSocket error!\x1b[0m');
                console.error('WebSocket error:', error);
            };

            this.ws.onclose = () => {
                this.term.writeln('');
                this.term.writeln('\x1b[1;33mConnection closed\x1b[0m');
            };
        } catch (error) {
            this.term.writeln('\x1b[1;31mFailed to connect: ' + error.message + '\x1b[0m');
        }
    }

    /**
     * Setup input handling
     */
    setupInput() {
        let currentLine = '';

        this.term.onData((data) => {
            switch (data) {
                case '\r': // Enter
                    this.term.write('\r\n');
                    if (currentLine.trim()) {
                        this.sendCommand(currentLine.trim());
                    }
                    currentLine = '';
                    break;

                case '\u007F': // Backspace
                    if (currentLine.length > 0) {
                        currentLine = currentLine.slice(0, -1);
                        this.term.write('\b \b');
                    }
                    break;

                case '\u0003': // Ctrl+C
                    this.term.write('^C\r\n');
                    currentLine = '';
                    break;

                default:
                    if (data >= String.fromCharCode(0x20) && data <= String.fromCharCode(0x7E)) {
                        currentLine += data;
                        this.term.write(data);
                    }
            }
        });
    }

    /**
     * Send command to server
     */
    sendCommand(command) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(command);
        } else {
            this.term.writeln('\x1b[1;31mNot connected to server\x1b[0m');
        }
    }

    /**
     * Disconnect and cleanup
     */
    disconnect() {
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        if (this.term) {
            this.term.dispose();
            this.term = null;
        }
    }
}
