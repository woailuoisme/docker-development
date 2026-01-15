/**
 * MQTT Topic Generator
 * Generates MQTT topics for device status messages
 */

/**
 * Generate MQTT topic for device status
 * @param {string} deviceId - The device identifier
 * @returns {string} The MQTT topic in format devices/{device_id}/status
 */
function generateDeviceStatusTopic(deviceId) {
    return `devices/${deviceId}/status`;
}

module.exports = {
    generateDeviceStatusTopic
};
