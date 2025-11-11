/**
 * Mineclifford API Client
 * Handles all HTTP requests to the backend API
 */
class MinecliffordAPI {
    constructor(baseURL = null) {
        // Auto-detect base URL:
        // - If port 3000 (dev server), use localhost:8000
        // - Otherwise (nginx), use same origin (empty string for relative URLs)
        if (baseURL === null) {
            const port = window.location.port;
            if (port === '3000') {
                // Development mode
                this.baseURL = 'http://localhost:8000';
            } else {
                // Production mode (nginx proxy)
                this.baseURL = '';
            }
        } else {
            this.baseURL = baseURL;
        }
    }

    /**
     * Generic request wrapper
     */
    async request(endpoint, options = {}) {
        const url = `${this.baseURL}${endpoint}`;

        try {
            const response = await fetch(url, options);

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.detail || `API Error: ${response.statusText}`);
            }

            return response.json();
        } catch (error) {
            console.error('API Request failed:', error);
            throw error;
        }
    }

    // Health & Status
    async getHealth() {
        return this.request('/api/health');
    }

    // Versions
    async getServerTypes() {
        return this.request('/api/versions/types');
    }

    async getVersions(serverType, mcVersion = null, limit = 20) {
        const params = new URLSearchParams();
        if (mcVersion) params.append('mc_version', mcVersion);
        params.append('limit', limit);

        return this.request(`/api/versions/${serverType}?${params}`);
    }

    async getLatestVersion(serverType, mcVersion = null) {
        const params = mcVersion ? `?mc_version=${mcVersion}` : '';
        return this.request(`/api/versions/${serverType}/latest${params}`);
    }

    // Servers
    async getServers() {
        return this.request('/api/servers/');
    }

    async getServer(id) {
        return this.request(`/api/servers/${id}`);
    }

    async createServer(config) {
        return this.request('/api/servers/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(config)
        });
    }

    async deleteServer(id) {
        return this.request(`/api/servers/${id}`, {
            method: 'DELETE'
        });
    }

    async startServer(id) {
        return this.request(`/api/servers/${id}/start`, {
            method: 'POST'
        });
    }

    async stopServer(id) {
        return this.request(`/api/servers/${id}/stop`, {
            method: 'POST'
        });
    }

    async restartServer(id) {
        return this.request(`/api/servers/${id}/restart`, {
            method: 'POST'
        });
    }

    // Monitoring
    async getMetrics() {
        return this.request('/api/monitoring/metrics');
    }

    // WebSocket for console
    createConsoleWebSocket(serverId) {
        let wsURL;
        if (this.baseURL === '') {
            // Production mode (nginx): use current host with ws/wss
            const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
            wsURL = `${protocol}//${window.location.host}`;
        } else {
            // Development mode: convert http to ws
            wsURL = this.baseURL.replace('http', 'ws');
        }
        return new WebSocket(`${wsURL}/api/console/${serverId}`);
    }
}
