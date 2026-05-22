'use client'

import { Canvas } from '@react-three/fiber'
import { OrbitControls, Sphere, MeshDistortMaterial } from '@react-three/drei'
import { useRef } from 'react'
import * as THREE from 'three'

export function Hero3DBackground() {
  const meshRef = useRef<THREE.Mesh>(null!)

  return (
    <div className="canvas-container">
      <Canvas camera={{ position: [0, 0, 5], fov: 75 }}>
        <ambientLight intensity={0.5} />
        <directionalLight position={[10, 10, 5]} intensity={1} />
        <pointLight position={[-10, -10, -5]} intensity={0.5} color="#8B5CF6" />

        {/* Main distorted sphere */}
        <Sphere ref={meshRef} args={[1.5, 100, 100]} position={[0, 0, 0]}>
          <MeshDistortMaterial
            color="#8B5CF6"
            attach="material"
            distort={0.4}
            speed={2}
            roughness={0.2}
            metalness={0.8}
          />
        </Sphere>

        {/* Floating particles */}
        {Array.from({ length: 50 }).map((_, i) => (
          <FloatingParticle key={i} index={i} />
        ))}

        <OrbitControls
          enableZoom={false}
          enablePan={false}
          autoRotate
          autoRotateSpeed={0.5}
        />
      </Canvas>
    </div>
  )
}

function FloatingParticle({ index }: { index: number }) {
  const ref = useRef<THREE.Mesh>(null!)
  const position = useRef({
    x: (Math.random() - 0.5) * 10,
    y: (Math.random() - 0.5) * 10,
    z: (Math.random() - 0.5) * 5,
  })

  return (
    <mesh ref={ref} position={[position.current.x, position.current.y, position.current.z]}>
      <sphereGeometry args={[0.02, 8, 8]} />
      <meshStandardMaterial
        color={index % 2 === 0 ? '#8B5CF6' : '#A78BFA'}
        transparent
        opacity={0.6}
      />
    </mesh>
  )
}
