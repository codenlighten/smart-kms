<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Navigation -->
    <nav class="bg-white shadow-sm border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <h1 class="text-xl font-bold text-gray-900">Universal Foundation</h1>
              <p class="text-sm text-gray-500">Admin Dashboard</p>
            </div>
          </div>
          <div class="flex items-center space-x-4">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
              {{ serviceStatus }}
            </span>
          </div>
        </div>
      </div>
    </nav>

    <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <!-- Stats Overview -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <KeyIcon class="h-6 w-6 text-gray-400" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Total KMS Keys
                  </dt>
                  <dd class="text-lg font-medium text-gray-900">
                    {{ stats.totalKeys }}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <DocumentTextIcon class="h-6 w-6 text-gray-400" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Signatures Today
                  </dt>
                  <dd class="text-lg font-medium text-gray-900">
                    {{ stats.signaturesTotal }}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <UsersIcon class="h-6 w-6 text-gray-400" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Active Tenants
                  </dt>
                  <dd class="text-lg font-medium text-gray-900">
                    {{ stats.activeTenants }}
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white overflow-hidden shadow rounded-lg">
          <div class="p-5">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <ClockIcon class="h-6 w-6 text-gray-400" />
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">
                    Avg Response Time
                  </dt>
                  <dd class="text-lg font-medium text-gray-900">
                    {{ stats.avgResponseTime }}ms
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Recent Signatures -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              Recent Signatures
            </h3>
            <div class="flow-root">
              <ul class="-my-5 divide-y divide-gray-200">
                <li v-for="signature in recentSignatures" :key="signature.id" class="py-4">
                  <div class="flex items-center space-x-4">
                    <div class="flex-shrink-0">
                      <div class="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center">
                        <DocumentTextIcon class="h-4 w-4 text-blue-600" />
                      </div>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-900 truncate">
                        {{ signature.tenant }}
                      </p>
                      <p class="text-sm text-gray-500 truncate">
                        {{ signature.keyRef }}
                      </p>
                    </div>
                    <div class="flex-shrink-0 text-sm text-gray-500">
                      {{ formatTime(signature.timestamp) }}
                    </div>
                  </div>
                </li>
              </ul>
            </div>
            <div class="mt-6">
              <button @click="testSignature" 
                class="w-full bg-blue-600 border border-transparent rounded-md py-2 px-4 text-sm font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500">
                Test Signature
              </button>
            </div>
          </div>
        </div>

        <!-- KMS Keys Management -->
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
              KMS Keys
            </h3>
            <div class="space-y-4">
              <div v-for="key in kmsKeys" :key="key.alias" 
                class="border border-gray-200 rounded-lg p-4">
                <div class="flex items-center justify-between">
                  <div>
                    <h4 class="text-sm font-medium text-gray-900">{{ key.alias }}</h4>
                    <p class="text-xs text-gray-500">{{ key.keyId }}</p>
                  </div>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    Active
                  </span>
                </div>
                <div class="mt-2 text-xs text-gray-600">
                  Curve: secp256k1 | Usage: {{ key.usage }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- System Health -->
      <div class="mt-8 bg-white shadow rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">
            System Health
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">{{ systemHealth.uptime }}</div>
              <div class="text-sm text-gray-500">Uptime</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600">{{ systemHealth.requestsPerMin }}</div>
              <div class="text-sm text-gray-500">Requests/min</div>
            </div>
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600">{{ systemHealth.errorRate }}%</div>
              <div class="text-sm text-gray-500">Error Rate</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { 
  KeyIcon, 
  DocumentTextIcon, 
  UsersIcon, 
  ClockIcon 
} from '@heroicons/vue/24/outline'
import { format } from 'date-fns'

// Reactive data
const serviceStatus = ref('Online')
const stats = ref({
  totalKeys: 2,
  signaturesTotal: 0,
  activeTenants: 1,
  avgResponseTime: 0
})

const recentSignatures = ref([])
const kmsKeys = ref([
  {
    alias: 'alias/bsv/tenant/T123/anchor',
    keyId: '4d1451c6-d096-4b15-850b-98ab5c656548',
    usage: 'SIGN_VERIFY'
  },
  {
    alias: 'alias/bsv/tenant/T123/issue', 
    keyId: '44651bc8-bdf7-465c-8743-50b27851b653',
    usage: 'SIGN_VERIFY'
  }
])

const systemHealth = ref({
  uptime: '0m',
  requestsPerMin: 0,
  errorRate: 0
})

// Functions
const formatTime = (timestamp: string) => {
  return format(new Date(timestamp), 'HH:mm:ss')
}

const checkServiceHealth = async () => {
  try {
    const response = await fetch('/api/v1/health')
    if (response.ok) {
      serviceStatus.value = 'Online'
      const data = await response.json()
      // Update stats based on health check
    } else {
      serviceStatus.value = 'Offline'
    }
  } catch (error) {
    serviceStatus.value = 'Offline'
    console.error('Health check failed:', error)
  }
}

const testSignature = async () => {
  try {
    const testPayload = {
      idempotencyKey: `admin-test-${Date.now()}`,
      schemaVersion: "1.0",
      actor: {
        did: "did:web:admin.universal-foundation.org",
        tenant: "T123"
      },
      payload: {
        digestHex: "7f83b1657ff1fc53b92dc18148a1d65dfa1350cba0d7055f1b3a2842a8f5f7f7",
        keyRef: "alias/bsv/tenant/T123/anchor"
      },
      options: {
        receiptOnly: true
      }
    }

    const response = await fetch('/api/v1/sign', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(testPayload)
    })

    const result = await response.json()
    
    if (response.ok) {
      // Add to recent signatures
      recentSignatures.value.unshift({
        id: result.policyReceipt.subject.id,
        tenant: 'T123',
        keyRef: testPayload.payload.keyRef,
        timestamp: result.policyReceipt.issuedAt
      })
      
      // Keep only last 5
      recentSignatures.value = recentSignatures.value.slice(0, 5)
      
      // Update stats
      stats.value.signaturesTotal += 1
      
      alert('Test signature successful!')
    } else {
      alert(`Test failed: ${result.error}`)
    }
  } catch (error) {
    console.error('Test signature failed:', error)
    alert('Test signature failed')
  }
}

// Lifecycle
onMounted(() => {
  checkServiceHealth()
  
  // Set up periodic health checks
  setInterval(checkServiceHealth, 30000) // Every 30 seconds
  
  // Update uptime display
  const startTime = Date.now()
  setInterval(() => {
    const uptimeMs = Date.now() - startTime
    const uptimeMin = Math.floor(uptimeMs / 60000)
    systemHealth.value.uptime = `${uptimeMin}m`
  }, 1000)
})
</script>
