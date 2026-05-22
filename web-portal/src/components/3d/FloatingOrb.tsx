'use client'

import { Canvas } from '@react-three/fiber'
import { Float, MeshDistortMaterial } from '@react-three/drei'
import { useRef } from 'react'
import * as THREE from 'three'

interface FloatingOrbProps {
  position?: [number, number, number]
  color?: string
  size?: number
  distort?: number
  speed?: number
}

export function FloatingOrb({
  position = [0, 0, 0],
  color = '#8B5CF6',
  size = 0.5,
  distort = 0.3,
  speed = 1.5,
}: FloatingOrbProps) {
  const meshRef = useRef<THREE.Mesh>(null!)

  return (
    <Float speed={speed} rotationIntensity={0.5} floatIntensity={1}>
      <mesh ref={meshRef} position={position as [number, number, number]}>
        <icosahedronGeometry args={[size, 4]} />
        <MeshDistortMaterial
          color={color}
          distort={distort}
          speed={speed}
          roughness={0.1}
          metalness={0.9}
          transparent
          opacity={0.8}
        />
      </mesh>
    </Float>
  )
}

export function OrbScene({ children }: { children?: React.ReactNode }) {
  return (
    <Canvas
      camera={{ position: [0, 0, 5], fov: 60 }}
      style={{ background: 'transparent' }}
    >
      <ambientLight intensity={0.4} />
      <directionalLight position={[5, 5, 5]} intensity={0.8} />
      <pointLight position={[-5, -5, -5]} intensity={0.3} color="#8B5CF6" />
      {children}
    </Canvas>
  )
}
