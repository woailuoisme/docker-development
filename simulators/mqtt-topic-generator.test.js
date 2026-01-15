/**
 * Property-Based Tests for MQTT Topic Generation
 * Feature: simplified-iot-device-monitoring
 */

const fc = require('fast-check');
const { generateDeviceStatusTopic } = require('./mqtt-topic-generator');

describe('MQTT Topic Generator', () => {
    /**
     * Feature: simplified-iot-device-monitoring, Property 7: MQTT 主题格式
     * Validates: Requirements 3.2
     * 
     * Property: For any valid device ID, the generated MQTT topic should follow
     * the format "devices/{device_id}/status"
     * 
     * Valid device IDs must not contain MQTT topic delimiters (/, +, #) or wildcards
     */
    test('Property 7: MQTT topic format - devices/{device_id}/status', () => {
        fc.assert(
            fc.property(
                // Generate valid device IDs (alphanumeric, hyphens, underscores)
                // Exclude MQTT special characters: /, +, #
                fc.string({ minLength: 1, maxLength: 50 })
                    .filter(s => s.trim().length > 0)
                    .filter(s => !s.includes('/'))  // No topic delimiters
                    .filter(s => !s.includes('+'))  // No single-level wildcards
                    .filter(s => !s.includes('#')), // No multi-level wildcards
                (deviceId) => {
                    const topic = generateDeviceStatusTopic(deviceId);
                    
                    // Property 1: Topic should start with "devices/"
                    expect(topic.startsWith('devices/')).toBe(true);
                    
                    // Property 2: Topic should end with "/status"
                    expect(topic.endsWith('/status')).toBe(true);
                    
                    // Property 3: Topic should contain the device ID
                    expect(topic).toContain(deviceId);
                    
                    // Property 4: Topic should match the exact format
                    const expectedTopic = `devices/${deviceId}/status`;
                    expect(topic).toBe(expectedTopic);
                    
                    // Property 5: Topic should have exactly 3 segments separated by "/"
                    const segments = topic.split('/');
                    expect(segments.length).toBe(3);
                    expect(segments[0]).toBe('devices');
                    expect(segments[1]).toBe(deviceId);
                    expect(segments[2]).toBe('status');
                }
            ),
            { numRuns: 100 } // Run 100 iterations as specified in design doc
        );
    });

    /**
     * Additional test: Verify with actual device IDs used in the simulator
     */
    test('MQTT topic format with actual device IDs', () => {
        const actualDeviceIds = ['VM001', 'VM002', 'VM003', 'VM004', 'VM005'];
        
        actualDeviceIds.forEach(deviceId => {
            const topic = generateDeviceStatusTopic(deviceId);
            expect(topic).toBe(`devices/${deviceId}/status`);
        });
    });
});
