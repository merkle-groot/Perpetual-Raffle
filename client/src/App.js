import './App.css';
import React from 'react';
import Nav from "../src/components/Nav";
import Dashboard from './components/Dashboard';

function App() {
  return (
    <div className="App">
      <Nav/>
      <Dashboard/>
    </div>
  );
}

export default App;
