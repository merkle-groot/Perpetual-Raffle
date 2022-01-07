import React from 'react';
import logo from '../images/logo.png';
import "./Nav.css";

function Nav(){
    return(
        <nav>
            <div className="logo-image">
                <img clasName="logo" src={logo} alt="logo"/>
            </div>
        </nav>
    )
}

export default Nav;