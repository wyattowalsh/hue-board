import * as React from 'react';import * as ReactDOM from 'react-dom';import {createRoot} from 'react-dom/client';import App from './App';
class ErrorBoundary extends React.Component<{children:React.ReactNode},{message:string}>{state={message:''};static getDerivedStateFromError(error:Error){return {message:error.message||String(error)}}componentDidCatch(error:Error){window.deckBootError(error.message||String(error))}render(){return this.state.message?<div role="alert" className="boot error"><h1>Interface error</h1><p>{this.state.message}</p><p>Close with Done and choose Compatibility controls. Your pairing is unchanged.</p></div>:this.props.children}}
const root=document.getElementById('root');if(!root)throw new Error('Interface root missing');
// A synchronous initial commit satisfies Scriptable's existing readiness handshake.
ReactDOM.flushSync(()=>createRoot(root).render(<ErrorBoundary><App/></ErrorBoundary>));
